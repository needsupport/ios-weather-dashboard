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
            return "Location is outside the United States. The National Weather Service API only covers U.S. locations."
        }
    }
}

// MARK: - NWS API Response Models
struct NWSPointResponse: Codable {
    let properties: NWSPointProperties
}

struct NWSPointProperties: Codable {
    let gridId: String
    let gridX: Int
    let gridY: Int
    let relativeLocation: NWSRelativeLocation
    let forecastHourly: String  // URL for hourly forecast
    let forecast: String        // URL for daily forecast
}

struct NWSRelativeLocation: Codable {
    let properties: NWSRelativeLocationProperties
}

struct NWSRelativeLocationProperties: Codable {
    let city: String
    let state: String
}

struct NWSForecastResponse: Codable {
    let properties: NWSForecastProperties
}

struct NWSForecastProperties: Codable {
    let periods: [NWSForecastPeriod]
    let updated: String
}

struct NWSForecastPeriod: Codable {
    let number: Int
    let name: String
    let startTime: String
    let endTime: String
    let isDaytime: Bool
    let temperature: Int
    let temperatureUnit: String
    let windSpeed: String
    let windDirection: String
    let icon: String?
    let shortForecast: String
    let detailedForecast: String
}

struct NWSAlertResponse: Codable {
    let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Codable {
    let properties: NWSAlertProperties
}

struct NWSAlertProperties: Codable {
    let id: String
    let event: String
    let headline: String?
    let description: String
    let severity: String
    let effective: String
    let ends: String?
    let expires: String
}

// MARK: - Service Protocol
protocol WeatherServiceProtocol {
    func fetchWeather(for coordinates: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error>
}

// MARK: - Service Implementation
class WeatherService: WeatherServiceProtocol {
    // MARK: - National Weather Service API Config
    private let baseURL = "https://api.weather.gov"
    
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
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
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
        
        // Check if location is within the US approximately
        // NWS API only works for US locations
        if !isLocationLikelyInUS(lat: lat, lon: lon) {
            #if DEBUG
            // Use demo data in DEBUG mode if location is outside US
            return Just((demoData, getDemoAlerts()))
                .delay(for: .seconds(1.5), scheduler: RunLoop.main)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            #else
            return Fail(error: WeatherError.locationOutsideUS).eraseToAnyPublisher()
            #endif
        }
        
        // For debugging, uncomment to use demo data
        // return Just((demoData, getDemoAlerts()))
        //     .delay(for: .seconds(1.5), scheduler: RunLoop.main)
        //     .setFailureType(to: Error.self)
        //     .eraseToAnyPublisher()
        
        // Step 1: Convert lat/lon to NWS grid points
        return getGridPoint(lat: lat, lon: lon)
            .flatMap { pointProperties -> AnyPublisher<(NWSPointProperties, NWSForecastResponse, NWSForecastResponse, NWSAlertResponse?), Error> in
                // Get relative location from point properties for location name
                let dailyForecastURL = URL(string: pointProperties.forecast)!
                let hourlyForecastURL = URL(string: pointProperties.forecastHourly)!
                
                // Step 2: Fetch daily and hourly forecasts in parallel
                let dailyForecast = self.fetchForecast(url: dailyForecastURL)
                let hourlyForecast = self.fetchForecast(url: hourlyForecastURL)
                
                // Step 3: Fetch alerts (which might be empty)
                let alerts = self.fetchAlerts(lat: lat, lon: lon)
                    .catch { error -> AnyPublisher<NWSAlertResponse?, Error> in
                        // If alerts fail, just return nil and continue
                        print("Error fetching alerts: \(error)")
                        return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                
                // Combine all responses
                return Publishers.CombineLatest4(
                    Just(pointProperties).setFailureType(to: Error.self),
                    dailyForecast,
                    hourlyForecast,
                    alerts
                ).eraseToAnyPublisher()
            }
            .map { pointProperties, dailyForecast, hourlyForecast, alertsResponse -> (WeatherData, [WeatherAlert]) in
                // Step 4: Convert the responses to our data model
                var weatherData = WeatherData()
                
                // Set location from point properties
                weatherData.location = "\(pointProperties.relativeLocation.properties.city), \(pointProperties.relativeLocation.properties.state)"
                
                // Create metadata
                weatherData.metadata = WeatherMetadata(
                    office: pointProperties.gridId,
                    gridX: String(pointProperties.gridX),
                    gridY: String(pointProperties.gridY),
                    timezone: TimeZone.current.identifier,
                    updated: dailyForecast.properties.updated
                )
                
                // Process daily forecast periods
                // NWS gives day/night separate periods, so we need to combine them
                let calendar = Calendar.current
                var dailyForecasts: [DailyForecast] = []
                
                var currentDay: (date: Date, high: Double, low: Double, day: NWSForecastPeriod?, night: NWSForecastPeriod?)?
                
                for period in dailyForecast.properties.periods {
                    guard let periodDate = self.dateFormatter.date(from: period.startTime) else { continue }
                    
                    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: periodDate) ?? 0
                    
                    if currentDay == nil || calendar.ordinality(of: .day, in: .year, for: currentDay!.date) != dayOfYear {
                        // Save previous day if exists
                        if let day = currentDay, day.day != nil {
                            let forecast = self.createDailyForecast(
                                date: day.date,
                                high: day.high,
                                low: day.low,
                                dayPeriod: day.day,
                                nightPeriod: day.night
                            )
                            dailyForecasts.append(forecast)
                        }
                        
                        // Start new day
                        currentDay = (date: periodDate, high: 0, low: 0, day: nil, night: nil)
                    }
                    
                    if period.isDaytime {
                        currentDay?.day = period
                        currentDay?.high = Double(period.temperature)
                    } else {
                        currentDay?.night = period
                        currentDay?.low = Double(period.temperature)
                    }
                }
                
                // Add the last day
                if let day = currentDay, day.day != nil {
                    let forecast = createDailyForecast(
                        date: day.date,
                        high: day.high,
                        low: day.low,
                        dayPeriod: day.day,
                        nightPeriod: day.night
                    )
                    dailyForecasts.append(forecast)
                }
                
                weatherData.daily = dailyForecasts.sorted { $0.date < $1.date }
                
                // Process hourly forecast
                var hourlyForecasts: [HourlyForecast] = []
                
                for period in hourlyForecast.properties.periods.prefix(24) { // Limit to 24 hours
                    guard let periodDate = self.dateFormatter.date(from: period.startTime) else { continue }
                    
                    let hourFormatter = DateFormatter()
                    hourFormatter.dateFormat = "ha"
                    
                    let hourlyForecast = HourlyForecast(
                        id: "hour-\(period.number)",
                        time: hourFormatter.string(from: periodDate).lowercased(),
                        temperature: Double(period.temperature),
                        icon: self.getNWSIconName(period.icon),
                        shortForecast: period.shortForecast,
                        windSpeed: self.parseWindSpeed(period.windSpeed),
                        windDirection: period.windDirection,
                        isDaytime: period.isDaytime
                    )
                    
                    hourlyForecasts.append(hourlyForecast)
                }
                
                weatherData.hourly = hourlyForecasts
                
                // Process alerts
                var alerts: [WeatherAlert] = []
                
                if let alertResponse = alertsResponse {
                    for feature in alertResponse.features {
                        guard let startDate = self.dateFormatter.date(from: feature.properties.effective) else { continue }
                        
                        let endDate: Date?
                        if let ends = feature.properties.ends {
                            endDate = self.dateFormatter.date(from: ends)
                        } else {
                            endDate = self.dateFormatter.date(from: feature.properties.expires)
                        }
                        
                        let alert = WeatherAlert(
                            id: feature.properties.id,
                            headline: feature.properties.headline ?? feature.properties.event,
                            description: feature.properties.description,
                            severity: feature.properties.severity,
                            event: feature.properties.event,
                            start: startDate,
                            end: endDate
                        )
                        
                        alerts.append(alert)
                    }
                }
                
                return (weatherData, alerts)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    // Create daily forecast from combined day/night periods
    private func createDailyForecast(date: Date, high: Double, low: Double, dayPeriod: NWSForecastPeriod?, nightPeriod: NWSForecastPeriod?) -> DailyForecast {
        let calendar = Calendar.current
        
        // Use either day or night period data, preferring day
        let period = dayPeriod ?? nightPeriod!
        
        let windSpeed = parseWindSpeed(period.windSpeed)
        
        return DailyForecast(
            id: "day-\(calendar.component(.day, from: date))",
            day: dayFormatter.string(from: date),
            fullDay: fullDayFormatter.string(from: date),
            date: date,
            tempHigh: high,
            tempLow: low,
            precipitation: Precipitation(chance: 30), // NWS doesn't provide this directly
            uvIndex: 5, // NWS doesn't provide this
            wind: Wind(speed: windSpeed, direction: period.windDirection),
            icon: getNWSIconName(period.icon),
            detailedForecast: dayPeriod?.detailedForecast ?? nightPeriod?.detailedForecast ?? "",
            shortForecast: dayPeriod?.shortForecast ?? nightPeriod?.shortForecast ?? "",
            humidity: nil, // NWS doesn't provide this
            dewpoint: nil, // NWS doesn't provide this
            pressure: nil, // NWS doesn't provide this
            skyCover: nil  // NWS doesn't provide this
        )
    }
    
    // Extract a simpler name from NWS icon URLs
    private func getNWSIconName(_ iconURL: String?) -> String {
        guard let iconURL = iconURL else { return "cloud" }
        
        if iconURL.contains("skc") || iconURL.contains("few") { return "sun" }
        if iconURL.contains("sct") || iconURL.contains("bkn") { return "cloud" }
        if iconURL.contains("rain") || iconURL.contains("shower") { return "rain" }
        if iconURL.contains("snow") || iconURL.contains("sleet") { return "snow" }
        if iconURL.contains("fog") { return "cloud" }
        if iconURL.contains("wind") { return "cloud" } // No direct wind icon mapping
        if iconURL.contains("tstorm") { return "rain" }
        
        return "cloud" // Default
    }
    
    // Parse wind speed from string like "10 mph" to numeric value
    private func parseWindSpeed(_ windString: String) -> Double {
        let components = windString.components(separatedBy: " ")
        if components.count >= 1, let speed = Double(components[0]) {
            return speed
        }
        return 0.0
    }
    
    // Check if coordinates are roughly within the US
    private func isLocationLikelyInUS(lat: Double, lon: Double) -> Bool {
        // Simple bounding box check for continental US, Alaska, and Hawaii
        return (lat >= 24.0 && lat <= 50.0 && lon >= -125.0 && lon <= -66.0) || // Continental US
               (lat >= 51.0 && lat <= 72.0 && lon >= -169.0 && lon <= -129.0) || // Alaska
               (lat >= 18.0 && lat <= 29.0 && lon >= -160.0 && lon <= -154.0)    // Hawaii
    }
    
    // Get grid point information from lat/lon
    private func getGridPoint(lat: Double, lon: Double) -> AnyPublisher<NWSPointProperties, Error> {
        guard let url = URL(string: "\(baseURL)/points/\(lat),\(lon)") else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("iOS-Weather-App (your-contact-email@example.com)", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .map { $0.data }
            .decode(type: NWSPointResponse.self, decoder: JSONDecoder())
            .map { $0.properties }
            .mapError { error -> Error in
                if let decodingError = error as? DecodingError {
                    return WeatherError.decodingError(decodingError)
                }
                return error
            }
            .eraseToAnyPublisher()
    }
    
    // Fetch forecast data from URL
    private func fetchForecast(url: URL) -> AnyPublisher<NWSForecastResponse, Error> {
        var request = URLRequest(url: url)
        request.addValue("iOS-Weather-App (your-contact-email@example.com)", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .map { $0.data }
            .decode(type: NWSForecastResponse.self, decoder: JSONDecoder())
            .mapError { error -> Error in
                if let decodingError = error as? DecodingError {
                    return WeatherError.decodingError(decodingError)
                }
                return error
            }
            .eraseToAnyPublisher()
    }
    
    // Fetch alerts for a location
    private func fetchAlerts(lat: Double, lon: Double) -> AnyPublisher<NWSAlertResponse?, Error> {
        guard let url = URL(string: "\(baseURL)/alerts/active?point=\(lat),\(lon)") else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("iOS-Weather-App (your-contact-email@example.com)", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .map { $0.data }
            .decode(type: NWSAlertResponse.self, decoder: JSONDecoder())
            .mapError { error -> Error in
                if let decodingError = error as? DecodingError {
                    return WeatherError.decodingError(decodingError)
                }
                return error
            }
            .eraseToAnyPublisher()
    }
    
    // Generate demo alerts for testing
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
