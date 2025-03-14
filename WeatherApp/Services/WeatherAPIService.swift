import Foundation
import Combine
import CoreLocation

// MARK: - API Protocol
protocol WeatherAPIProtocol {
    func fetchWeatherData(for location: CLLocationCoordinate2D, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError>
    func fetchWeatherData(for cityName: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError>
}

// MARK: - API Response Structure
struct APIResponse {
    var weatherData: WeatherData
    var alerts: [WeatherAlert]
}

// MARK: - Open Weather Map Implementation
class OpenWeatherMapAPI: WeatherAPIProtocol {
    private let apiKey: String
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func fetchWeatherData(for location: CLLocationCoordinate2D, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError> {
        let endpoint = "\(baseURL)/onecall?lat=\(location.latitude)&lon=\(location.longitude)&appid=\(apiKey)&units=\(unit == .celsius ? "metric" : "imperial")&exclude=minutely"
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetchData(from: url, location: location)
    }
    
    func fetchWeatherData(for cityName: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError> {
        // First get coordinates for the city name
        let geocodingEndpoint = "https://api.openweathermap.org/geo/1.0/direct?q=\(cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=1&appid=\(apiKey)"
        
        guard let url = URL(string: geocodingEndpoint) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .mapError { WeatherError.networkError($0) }
            .tryMap { data, response -> CLLocationCoordinate2D in
                guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                    throw WeatherError.apiError("Invalid response from server")
                }
                
                let geocodingResults = try JSONDecoder().decode([GeocodingResult].self, from: data)
                guard let first = geocodingResults.first else {
                    throw WeatherError.apiError("City not found")
                }
                
                return CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)
            }
            .flatMap { coordinates in
                self.fetchWeatherData(for: coordinates, unit: unit)
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchData(from url: URL, location: CLLocationCoordinate2D) -> AnyPublisher<APIResponse, WeatherError> {
        return URLSession.shared.dataTaskPublisher(for: url)
            .mapError { WeatherError.networkError($0) }
            .tryMap { data, response -> (Data, HTTPURLResponse) in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WeatherError.apiError("Invalid response")
                }
                return (data, httpResponse)
            }
            .tryMap { data, response -> OpenWeatherResponse in
                guard 200..<300 ~= response.statusCode else {
                    if response.statusCode == 401 {
                        throw WeatherError.apiError("Invalid API key")
                    } else {
                        throw WeatherError.apiError("Server error: \(response.statusCode)")
                    }
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                do {
                    return try decoder.decode(OpenWeatherResponse.self, from: data)
                } catch {
                    throw WeatherError.decodingError(error)
                }
            }
            .flatMap { openWeatherResponse -> AnyPublisher<(OpenWeatherResponse, String), WeatherError> in
                // Get location name using reverse geocoding
                return self.getLocationName(for: location)
                    .map { locationName in
                        return (openWeatherResponse, locationName)
                    }
                    .eraseToAnyPublisher()
            }
            .map { openWeatherResponse, locationName -> APIResponse in
                // Convert from OpenWeather model to our app model
                let weatherData = self.convertResponseToWeatherData(response: openWeatherResponse, locationName: locationName)
                let alerts = self.convertResponseToAlerts(response: openWeatherResponse)
                
                return APIResponse(weatherData: weatherData, alerts: alerts)
            }
            .eraseToAnyPublisher()
    }
    
    private func getLocationName(for location: CLLocationCoordinate2D) -> AnyPublisher<String, WeatherError> {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        return Future<String, WeatherError> { promise in
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                if let error = error {
                    promise(.failure(WeatherError.apiError("Geocoding error: \(error.localizedDescription)")))
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
                    promise(.success("Unknown Location"))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // Convert OpenWeather response to our WeatherData model
    private func convertResponseToWeatherData(response: OpenWeatherResponse, locationName: String) -> WeatherData {
        var weatherData = WeatherData()
        weatherData.location = locationName
        
        // Set daily forecasts
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"
        
        let fullDayFormatter = DateFormatter()
        fullDayFormatter.dateFormat = "EEEE"
        
        if let daily = response.daily {
            for (index, day) in daily.enumerated() {
                let date = Date(timeIntervalSince1970: TimeInterval(day.dt))
                
                let forecast = DailyForecast(
                    id: "day-\(index)",
                    day: dayFormatter.string(from: date),
                    fullDay: fullDayFormatter.string(from: date),
                    date: date,
                    tempHigh: day.temp.max,
                    tempLow: day.temp.min,
                    precipitation: Precipitation(chance: (day.pop ?? 0) * 100),
                    uvIndex: Int(day.uvi ?? 0),
                    wind: Wind(speed: day.wind_speed ?? 0, direction: getWindDirection(day.wind_deg ?? 0)),
                    icon: getIconCode(day.weather?.first?.id ?? 0, day.weather?.first?.icon ?? ""),
                    detailedForecast: day.weather?.first?.description?.capitalized ?? "No Description Available",
                    shortForecast: day.weather?.first?.main ?? "Unknown",
                    humidity: day.humidity,
                    dewpoint: day.dew_point,
                    pressure: day.pressure,
                    skyCover: nil // OpenWeather doesn't provide cloud cover in the daily forecast
                )
                
                weatherData.daily.append(forecast)
            }
        }
        
        // Set hourly forecasts
        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "ha"
        
        if let hourly = response.hourly {
            for (index, hour) in hourly.prefix(24).enumerated() {
                let date = Date(timeIntervalSince1970: TimeInterval(hour.dt))
                let hourString = hourFormatter.string(from: date).lowercased()
                
                let isDaytime = calendar.component(.hour, from: date) >= 6 && calendar.component(.hour, from: date) < 18
                
                let forecast = HourlyForecast(
                    id: "hour-\(index)",
                    time: hourString,
                    temperature: hour.temp,
                    icon: getIconCode(hour.weather?.first?.id ?? 0, hour.weather?.first?.icon ?? ""),
                    shortForecast: hour.weather?.first?.main ?? "Unknown",
                    windSpeed: hour.wind_speed ?? 0,
                    windDirection: getWindDirection(hour.wind_deg ?? 0),
                    isDaytime: isDaytime
                )
                
                weatherData.hourly.append(forecast)
            }
        }
        
        // Set metadata
        let metadata = WeatherMetadata(
            office: "OpenWeatherMap",
            gridX: "",
            gridY: "",
            timezone: response.timezone ?? "Unknown",
            updated: dateToString(Date(timeIntervalSince1970: TimeInterval(response.current?.dt ?? 0)))
        )
        weatherData.metadata = metadata
        
        return weatherData
    }
    
    // Convert OpenWeather alerts to our WeatherAlert model
    private func convertResponseToAlerts(response: OpenWeatherResponse) -> [WeatherAlert] {
        var alerts: [WeatherAlert] = []
        
        if let apiAlerts = response.alerts {
            for (index, alert) in apiAlerts.enumerated() {
                let weatherAlert = WeatherAlert(
                    id: "alert-\(index)",
                    headline: alert.event ?? "Weather Alert",
                    description: alert.description ?? "No details available",
                    severity: getSeverity(from: alert.tags),
                    event: alert.event ?? "Weather Alert",
                    start: Date(timeIntervalSince1970: TimeInterval(alert.start ?? 0)),
                    end: alert.end != nil ? Date(timeIntervalSince1970: TimeInterval(alert.end!)) : nil
                )
                alerts.append(weatherAlert)
            }
        }
        
        return alerts
    }
    
    // Helper functions
    private func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getWindDirection(_ degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    private func getIconCode(_ weatherId: Int, _ iconCode: String) -> String {
        let isDaytime = !iconCode.contains("n")
        
        // Convert OpenWeather codes to our app codes
        switch weatherId {
        case 200...232: // Thunderstorm
            return "cloud.bolt"
        case 300...321: // Drizzle
            return "cloud.drizzle"
        case 500...531: // Rain
            return "cloud.rain"
        case 600...622: // Snow
            return "cloud.snow"
        case 701...781: // Atmosphere (fog, mist, etc.)
            return "cloud.fog"
        case 800: // Clear
            return isDaytime ? "sun" : "moon"
        case 801...802: // Few clouds
            return isDaytime ? "cloud.sun" : "cloud.moon"
        case 803...804: // Broken/overcast clouds
            return "cloud"
        default:
            return "cloud"
        }
    }
    
    private func getSeverity(from tags: [String]?) -> String {
        guard let tags = tags else { return "moderate" }
        
        if tags.contains("Extreme") {
            return "extreme"
        } else if tags.contains("Severe") {
            return "severe"
        } else if tags.contains("Moderate") {
            return "moderate"
        } else {
            return "minor"
        }
    }
}

// MARK: - National Weather Service Implementation
class NWSWeatherAPI: WeatherAPIProtocol {
    private let baseURL = "https://api.weather.gov"
    
    func fetchWeatherData(for location: CLLocationCoordinate2D, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError> {
        // Implementation for NWS API would go here
        // This is complex and requires multiple API calls to the NWS endpoints
        // For brevity, return a placeholder implementation
        
        return Fail(error: WeatherError.apiError("NWS API not fully implemented yet")).eraseToAnyPublisher()
    }
    
    func fetchWeatherData(for cityName: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError> {
        // NWS doesn't support city name lookup directly
        return Fail(error: WeatherError.apiError("NWS API doesn't support city name lookup")).eraseToAnyPublisher()
    }
}

// MARK: - OpenWeather Response Models
struct OpenWeatherResponse: Codable {
    let lat: Double?
    let lon: Double?
    let timezone: String?
    let timezone_offset: Int?
    let current: CurrentWeather?
    let hourly: [HourlyWeather]?
    let daily: [DailyWeather]?
    let alerts: [WeatherAlert_OWM]?
}

struct CurrentWeather: Codable {
    let dt: Int
    let sunrise: Int?
    let sunset: Int?
    let temp: Double
    let feels_like: Double?
    let pressure: Double?
    let humidity: Double?
    let dew_point: Double?
    let uvi: Double?
    let clouds: Int?
    let visibility: Int?
    let wind_speed: Double?
    let wind_deg: Double?
    let wind_gust: Double?
    let weather: [WeatherCondition]?
}

struct HourlyWeather: Codable {
    let dt: Int
    let temp: Double
    let feels_like: Double?
    let pressure: Double?
    let humidity: Double?
    let dew_point: Double?
    let uvi: Double?
    let clouds: Int?
    let visibility: Int?
    let wind_speed: Double?
    let wind_deg: Double?
    let wind_gust: Double?
    let weather: [WeatherCondition]?
    let pop: Double?
}

struct DailyWeather: Codable {
    let dt: Int
    let sunrise: Int?
    let sunset: Int?
    let temp: Temperature
    let feels_like: FeelsLike?
    let pressure: Double?
    let humidity: Double?
    let dew_point: Double?
    let wind_speed: Double?
    let wind_deg: Double?
    let wind_gust: Double?
    let weather: [WeatherCondition]?
    let clouds: Int?
    let pop: Double?
    let uvi: Double?
    let rain: Double?
    let snow: Double?
}

struct Temperature: Codable {
    let day: Double
    let min: Double
    let max: Double
    let night: Double
    let eve: Double
    let morn: Double
}

struct FeelsLike: Codable {
    let day: Double
    let night: Double
    let eve: Double
    let morn: Double
}

struct WeatherCondition: Codable {
    let id: Int
    let main: String?
    let description: String?
    let icon: String?
}

struct WeatherAlert_OWM: Codable {
    let sender_name: String?
    let event: String?
    let start: Int?
    let end: Int?
    let description: String?
    let tags: [String]?
}

// MARK: - Geocoding Result
struct GeocodingResult: Codable {
    let name: String
    let lat: Double
    let lon: Double
    let country: String
    let state: String?
}

// MARK: - Weather Service Factory
class WeatherServiceFactory {
    static func createService(type: WeatherServiceType) -> WeatherAPIProtocol {
        switch type {
        case .openWeatherMap:
            return OpenWeatherMapAPI(apiKey: Secrets.openWeatherMapApiKey)
        case .nationalWeatherService:
            return NWSWeatherAPI()
        }
    }
    
    enum WeatherServiceType {
        case openWeatherMap
        case nationalWeatherService
    }
}

// MARK: - Secret API Keys (never commit actual keys to source control)
struct Secrets {
    // In a real app, these would be stored in a more secure way
    static let openWeatherMapApiKey = "YOUR_API_KEY"
}
