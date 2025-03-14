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
        }
    }
}

// MARK: - Service Protocol
protocol WeatherServiceProtocol {
    func fetchWeather(for coordinates: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error>
}

// MARK: - Service Implementation
class WeatherService: WeatherServiceProtocol {
    // MARK: - API Keys and Configuration
    private let openWeatherApiKey = "YOUR_OPENWEATHER_API_KEY" // Replace with your actual API key
    private let weatherKitEndpoint = "https://api.example.com/weatherkit" // Replace with actual endpoint
    
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
    
    // MARK: - Public Methods
    func fetchWeather(for coordinates: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error> {
        // For testing purposes, you can use the demo data instead of making an actual API call
        // Comment out the return statement below to implement the actual API call
        
        // Uncomment for testing with demo data
        // return Just((demoData, getDemoAlerts()))
        //     .delay(for: .seconds(1.5), scheduler: RunLoop.main) // Simulate network delay
        //     .setFailureType(to: Error.self)
        //     .eraseToAnyPublisher()
        
        // Actual API implementation
        let unitString = unit == .celsius ? "metric" : "imperial"
        let components = coordinates.split(separator: ",")
        
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]),
              let url = URL(string: "https://api.openweathermap.org/data/2.5/onecall?lat=\(lat)&lon=\(lon)&exclude=minutely&units=\(unitString)&appid=\(openWeatherApiKey)") else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        // Get location name using reverse geocoding
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lon)
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .mapError { WeatherError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<(WeatherData, [WeatherAlert], CLPlacemark?), Error> in
                // Parse API response
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                
                // We would need to parse the OpenWeather API response here
                // This is a placeholder for the actual implementation
                
                // For demo purposes, we'll use the demo data
                var weatherData = self.demoData
                
                // Get location name using reverse geocoding
                return Future<CLPlacemark?, Error> { promise in
                    geocoder.reverseGeocodeLocation(location) { placemarks, error in
                        if let error = error {
                            print("Geocoding error: \(error.localizedDescription)")
                            promise(.success(nil))
                            return
                        }
                        promise(.success(placemarks?.first))
                    }
                }
                .map { placemark -> (WeatherData, [WeatherAlert], CLPlacemark?) in
                    if let placemark = placemark {
                        var locationString = ""
                        if let locality = placemark.locality {
                            locationString += locality
                        }
                        if let administrativeArea = placemark.administrativeArea {
                            if !locationString.isEmpty {
                                locationString += ", "
                            }
                            locationString += administrativeArea
                        }
                        weatherData.location = locationString
                    }
                    return (weatherData, self.getDemoAlerts(), placemark)
                }
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            }
            .map { weatherData, alerts, _ in
                return (weatherData, alerts)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
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
