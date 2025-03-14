import Foundation
import Combine
import CoreLocation

// MARK: - Error Types
enum WeatherError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case noData
    case locationOutsideUS
    case unsupportedLocation
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .noData:
            return "No data received"
        case .locationOutsideUS:
            return "Location is outside the US. Using demo data."
        case .unsupportedLocation:
            return "This location is not supported. Using demo data."
        }
    }
}

// MARK: - Service Protocol
protocol WeatherServiceProtocol {
    func fetchWeather(for coordinates: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error>
    func fetchWeather(for cityName: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error>
}

// MARK: - Service Implementation
class WeatherService: WeatherServiceProtocol {
    // MARK: - Private Properties
    private let nwsAPI = NWSWeatherAPI()
    private let cacheManager = WeatherCacheManager.shared
    
    // Demo data - used for preview and offline fallback
    private let demoData: WeatherData = {
        var data = WeatherData()
        data.location = "San Francisco, CA"
        
        // Create some demo daily forecasts
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                let dailyForecast = DailyForecast(
                    id: "day-\(i)",
                    day: dayFormatter.string(from: date),
                    fullDay: fullDayFormatter.string(from: date),
                    date: date,
                    tempHigh: Double.random(in: 15...30),
                    tempLow: Double.random(in: 5...15),
                    precipitation: Precipitation(chance: Double.random(in: 0...100)),
                    uvIndex: Int.random(in: 0...11),
                    wind: Wind(speed: Double.random(in: 0...30), direction: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].randomElement() ?? "N"),
                    icon: ["sun", "cloud", "rain", "snow"].randomElement() ?? "sun",
                    detailedForecast: "Detailed forecast for \(dayFormatter.string(from: date))",
                    shortForecast: ["Sunny", "Partly cloudy", "Cloudy", "Rainy", "Snowy"].randomElement() ?? "Sunny",
                    humidity: Double.random(in: 30...90),
                    dewpoint: Double.random(in: 5...15),
                    pressure: Double.random(in: 980...1030),
                    skyCover: Double.random(in: 0...100)
                )
                data.daily.append(dailyForecast)
            }
        }
        
        // Create some demo hourly forecasts
        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "ha"
        
        for i in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: i, to: today) {
                let hourlyForecast = HourlyForecast(
                    id: "hour-\(i)",
                    time: hourFormatter.string(from: date).lowercased(),
                    temperature: Double.random(in: 10...25),
                    icon: ["sun", "cloud", "rain", "snow"].randomElement() ?? "sun",
                    shortForecast: ["Sunny", "Partly cloudy", "Cloudy", "Rainy"].randomElement() ?? "Sunny",
                    windSpeed: Double.random(in: 0...20),
                    windDirection: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].randomElement() ?? "N",
                    isDaytime: (6...18).contains(calendar.component(.hour, from: date))
                )
                data.hourly.append(hourlyForecast)
            }
        }
        
        // Create metadata
        let metadata = WeatherMetadata(
            office: "Demo",
            gridX: "0",
            gridY: "0",
            timezone: TimeZone.current.identifier,
            updated: dateFormatter.string(from: Date())
        )
        data.metadata = metadata
        
        return data
    }()
    
    // MARK: - Helper Properties
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
    
    private static let fullDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - Public Methods
    func fetchWeather(for coordinates: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error> {
        let components = coordinates.split(separator: ",")
        
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let cacheKey = "weather-\(coordinates)-\(unit.rawValue)"
        
        // Check if we have cached data
        if let cachedData = cacheManager.getWeatherData(for: cacheKey),
           let cachedAlerts = cacheManager.getWeatherAlerts(for: cacheKey) {
            print("Using cached weather data for \(coordinates)")
            return Just((cachedData, cachedAlerts))
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Check if location is in the US
        return isUSLocation(location)
            .flatMap { isUS -> AnyPublisher<APIResponse, WeatherError> in
                if isUS {
                    // Use NWS API for US locations
                    print("Using NWS API for US location: \(coordinates)")
                    return self.nwsAPI.fetchWeatherData(for: location, unit: unit)
                } else {
                    // For non-US locations, use demo data
                    print("Location outside US, using demo data for: \(coordinates)")
                    return self.useDemoData(for: location)
                        .mapError { $0 as? WeatherError ?? WeatherError.apiError($0.localizedDescription) }
                        .eraseToAnyPublisher()
                }
            }
            .map { apiResponse -> (WeatherData, [WeatherAlert]) in
                // Cache the results
                self.cacheManager.saveWeatherData(apiResponse.weatherData, for: cacheKey)
                self.cacheManager.saveWeatherAlerts(apiResponse.alerts, for: cacheKey)
                
                return (apiResponse.weatherData, apiResponse.alerts)
            }
            .catch { error -> AnyPublisher<(WeatherData, [WeatherAlert]), Error> in
                // On error, try to use cached data if available
                if let cachedData = self.cacheManager.getWeatherData(for: cacheKey),
                   let cachedAlerts = self.cacheManager.getWeatherAlerts(for: cacheKey) {
                    print("Error fetching data, using cached data for \(coordinates): \(error.localizedDescription)")
                    return Just((cachedData, cachedAlerts))
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // If no cached data, use demo data and add the error as an "alert"
                print("No cached data available, using demo data with error alert: \(error.localizedDescription)")
                var demoData = self.demoData
                let errorAlert = WeatherAlert(
                    id: "error-alert",
                    headline: "Data Error",
                    description: error.localizedDescription,
                    severity: "minor",
                    event: "API Error",
                    start: Date(),
                    end: Date().addingTimeInterval(86400)
                )
                
                // Update location in demo data
                self.updateLocationName(in: &demoData, for: location)
                
                // Return demo data with error alert
                return Just((demoData, [errorAlert]))
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func fetchWeather(for cityName: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error> {
        let cacheKey = "city-\(cityName)-\(unit.rawValue)"
        
        // Check if we have cached data
        if let cachedData = cacheManager.getWeatherData(for: cacheKey),
           let cachedAlerts = cacheManager.getWeatherAlerts(for: cacheKey) {
            print("Using cached weather data for city: \(cityName)")
            return Just((cachedData, cachedAlerts))
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Try to geocode the city name to get coordinates
        return geocodeCity(cityName)
            .flatMap { location in
                // Convert to string coordinates and call the other method
                let coordinates = "\(location.latitude),\(location.longitude)"
                return self.fetchWeather(for: coordinates, unit: unit)
            }
            .map { weatherData, alerts -> (WeatherData, [WeatherAlert]) in
                // Cache the results
                self.cacheManager.saveWeatherData(weatherData, for: cacheKey)
                self.cacheManager.saveWeatherAlerts(alerts, for: cacheKey)
                
                return (weatherData, alerts)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    /// Check if location is in the US
    private func isUSLocation(_ location: CLLocationCoordinate2D) -> AnyPublisher<Bool, WeatherError> {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        return Future<Bool, WeatherError> { promise in
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    promise(.success(false))
                    return
                }
                
                if let placemark = placemarks?.first,
                   let countryCode = placemark.isoCountryCode {
                    promise(.success(countryCode == "US"))
                } else {
                    promise(.success(false))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Get coordinates from city name
    private func geocodeCity(_ cityName: String) -> AnyPublisher<CLLocationCoordinate2D, Error> {
        let geocoder = CLGeocoder()
        
        return Future<CLLocationCoordinate2D, Error> { promise in
            geocoder.geocodeAddressString(cityName) { placemarks, error in
                if let error = error {
                    promise(.failure(WeatherError.apiError("Geocoding error: \(error.localizedDescription)")))
                    return
                }
                
                guard let location = placemarks?.first?.location else {
                    promise(.failure(WeatherError.apiError("Location not found")))
                    return
                }
                
                promise(.success(location.coordinate))
            }
        }.eraseToAnyPublisher()
    }
    
    /// Create demo data for a specific location
    private func useDemoData(for location: CLLocationCoordinate2D) -> AnyPublisher<APIResponse, Error> {
        var demoData = self.demoData
        
        return updateLocationName(in: &demoData, for: location)
            .map { locationName -> APIResponse in
                demoData.location = locationName
                return APIResponse(weatherData: demoData, alerts: self.getDemoAlerts())
            }
            .eraseToAnyPublisher()
    }
    
    /// Update the location name in demo data
    private func updateLocationName(in weatherData: inout WeatherData, for location: CLLocationCoordinate2D) -> AnyPublisher<String, Error> {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        return Future<String, Error> { promise in
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    promise(.success(weatherData.location))
                    return
                }
                
                if let placemark = placemarks?.first {
                    var locationName = ""
                    
                    if let locality = placemark.locality {
                        locationName = locality
                    }
                    
                    if let adminArea = placemark.administrativeArea, !adminArea.isEmpty {
                        if !locationName.isEmpty {
                            locationName += ", "
                        }
                        locationName += adminArea
                    }
                    
                    if locationName.isEmpty && placemark.name != nil {
                        locationName = placemark.name!
                    }
                    
                    promise(.success(locationName.isEmpty ? "Unknown Location" : locationName))
                } else {
                    promise(.success(weatherData.location))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Generate demo weather alerts
    private func getDemoAlerts() -> [WeatherAlert] {
        // Generate random demo weather alerts
        let alertTypes = [
            (event: "Severe Thunderstorm Warning", severity: "severe", description: "The National Weather Service has issued a severe thunderstorm warning for your area. Seek shelter immediately."),
            (event: "Heat Advisory", severity: "moderate", description: "A heat advisory is in effect. Stay hydrated and avoid prolonged exposure to the sun."),
            (event: "Flash Flood Watch", severity: "moderate", description: "A flash flood watch is in effect. Be prepared for possible flooding in your area."),
            (event: "Winter Storm Warning", severity: "severe", description: "A winter storm warning is in effect. Expect heavy snowfall and dangerous travel conditions.")
        ]
        
        // Randomly decide whether to return alerts
        let shouldHaveAlerts = Bool.random()
        guard shouldHaveAlerts else { return [] }
        
        // Generate 1-2 random alerts
        let numberOfAlerts = Int.random(in: 1...2)
        var alerts: [WeatherAlert] = []
        
        for i in 0..<numberOfAlerts {
            let alertType = alertTypes.randomElement()!
            let now = Date()
            let start = now.addingTimeInterval(Double.random(in: -3600...0)) // Start between 1 hour ago and now
            let end = now.addingTimeInterval(Double.random(in: 3600...86400)) // End between 1 hour and 1 day from now
            
            let alert = WeatherAlert(
                id: "alert-\(i)",
                headline: alertType.event,
                description: alertType.description,
                severity: alertType.severity,
                event: alertType.event,
                start: start,
                end: end
            )
            
            alerts.append(alert)
        }
        
        return alerts
    }
}

// MARK: - Date Formatter Extensions
private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "E"
    return formatter
}()

private let fullDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter
}()
