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
    private let decoder: JSONDecoder
    private let userAgent = "iOS-Weather-Dashboard/1.0 (github.com/needsupport/ios-weather-dashboard)"
    
    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func fetchWeatherData(for location: CLLocationCoordinate2D, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError> {
        // Multi-step API calls to NWS endpoints
        
        // 1. First get the grid points for the location
        return getGridPoints(for: location)
            .flatMap { gridInfo -> AnyPublisher<(NWSPointProperties, [NWSForecastPeriod], [NWSForecastPeriod]), WeatherError> in
                // 2. Fetch both daily and hourly forecasts in parallel
                return Publishers.Zip3(
                    Just(gridInfo).setFailureType(to: WeatherError.self),
                    self.getDailyForecast(from: gridInfo.forecast),
                    self.getHourlyForecast(from: gridInfo.forecastHourly)
                ).eraseToAnyPublisher()
            }
            .flatMap { gridInfo, dailyPeriods, hourlyPeriods -> AnyPublisher<(NWSPointProperties, [NWSForecastPeriod], [NWSForecastPeriod], [WeatherAlert]), WeatherError> in
                // 3. Fetch alerts
                return Publishers.Zip(
                    Just((gridInfo, dailyPeriods, hourlyPeriods)).setFailureType(to: WeatherError.self),
                    self.getAlerts(for: location)
                )
                .map { data, alerts in
                    return (data.0, data.1, data.2, alerts)
                }
                .eraseToAnyPublisher()
            }
            .map { gridInfo, dailyPeriods, hourlyPeriods, alerts -> APIResponse in
                // 4. Convert NWS data to our app's model format
                let weatherData = self.convertToWeatherData(
                    gridInfo: gridInfo,
                    dailyPeriods: dailyPeriods,
                    hourlyPeriods: hourlyPeriods,
                    unit: unit
                )
                
                return APIResponse(weatherData: weatherData, alerts: alerts)
            }
            .eraseToAnyPublisher()
    }
    
    func fetchWeatherData(for cityName: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError> {
        // NWS doesn't support city name lookup directly, we need to geocode first
        let geocoder = CLGeocoder()
        
        return Future<CLLocationCoordinate2D, WeatherError> { promise in
            geocoder.geocodeAddressString(cityName) { placemarks, error in
                if let error = error {
                    promise(.failure(WeatherError.apiError("Geocoding error: \(error.localizedDescription)")))
                    return
                }
                
                guard let location = placemarks?.first?.location?.coordinate else {
                    promise(.failure(WeatherError.apiError("Location not found")))
                    return
                }
                
                promise(.success(location))
            }
        }
        .flatMap { coordinates in
            self.fetchWeatherData(for: coordinates, unit: unit)
        }
        .eraseToAnyPublisher()
    }
    
    // Helper method to create URL request with proper headers
    private func createRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/geo+json", forHTTPHeaderField: "Accept")
        return request
    }
    
    // Get grid points from lat/lon
    private func getGridPoints(for location: CLLocationCoordinate2D) -> AnyPublisher<NWSPointProperties, WeatherError> {
        let endpoint = "\(baseURL)/points/\(location.latitude),\(location.longitude)"
        guard let url = URL(string: endpoint) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        let request = createRequest(for: url)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .map { $0.data }
            .decode(type: NWSPointsResponse.self, decoder: decoder)
            .mapError { error -> WeatherError in
                if let decodingError = error as? DecodingError {
                    return WeatherError.decodingError(decodingError)
                } else {
                    return WeatherError.apiError(error.localizedDescription)
                }
            }
            .map { $0.properties }
            .eraseToAnyPublisher()
    }
    
    // Get daily forecast
    private func getDailyForecast(from urlString: String) -> AnyPublisher<[NWSForecastPeriod], WeatherError> {
        guard let url = URL(string: urlString) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        let request = createRequest(for: url)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .map { $0.data }
            .decode(type: NWSForecastResponse.self, decoder: decoder)
            .mapError { WeatherError.decodingError($0) }
            .map { $0.properties.periods }
            .eraseToAnyPublisher()
    }
    
    // Get hourly forecast
    private func getHourlyForecast(from urlString: String) -> AnyPublisher<[NWSForecastPeriod], WeatherError> {
        guard let url = URL(string: urlString) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        let request = createRequest(for: url)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .map { $0.data }
            .decode(type: NWSForecastResponse.self, decoder: decoder)
            .mapError { WeatherError.decodingError($0) }
            .map { $0.properties.periods }
            .eraseToAnyPublisher()
    }
    
    // Get weather alerts
    private func getAlerts(for location: CLLocationCoordinate2D) -> AnyPublisher<[WeatherAlert], WeatherError> {
        let endpoint = "\(baseURL)/alerts/active?point=\(location.latitude),\(location.longitude)"
        guard let url = URL(string: endpoint) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        let request = createRequest(for: url)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .map { $0.data }
            .decode(type: NWSAlertResponse.self, decoder: decoder)
            .mapError { WeatherError.decodingError($0) }
            .map { response -> [WeatherAlert] in
                return response.features.map { feature in
                    return self.convertToWeatherAlert(feature.properties)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Convert NWS data to our WeatherData model
    private func convertToWeatherData(
        gridInfo: NWSPointProperties,
        dailyPeriods: [NWSForecastPeriod],
        hourlyPeriods: [NWSForecastPeriod],
        unit: WeatherViewModel.UserPreferences.TemperatureUnit
    ) -> WeatherData {
        var weatherData = WeatherData()
        
        // Set location
        if let relativeLocation = gridInfo.relativeLocation?.properties {
            weatherData.location = "\(relativeLocation.city), \(relativeLocation.state)"
        } else {
            weatherData.location = "Unknown Location"
        }
        
        // Set metadata
        let dateFormatter = ISO8601DateFormatter()
        let metadata = WeatherMetadata(
            office: gridInfo.gridId,
            gridX: String(gridInfo.gridX),
            gridY: String(gridInfo.gridY),
            timezone: gridInfo.timeZone ?? TimeZone.current.identifier,
            updated: Date().ISO8601Format()
        )
        weatherData.metadata = metadata
        
        // Process daily forecasts - NWS provides day/night periods, so we need to pair them
        let groupedDaily = groupDailyPeriods(dailyPeriods)
        weatherData.daily = groupedDaily.map { self.convertToDaily($0, unit: unit) }
        
        // Process hourly forecasts
        weatherData.hourly = hourlyPeriods.prefix(24).enumerated().map { index, period in
            return self.convertToHourly(period, index: index, unit: unit)
        }
        
        return weatherData
    }
    
    // Group day/night periods into single days
    private func groupDailyPeriods(_ periods: [NWSForecastPeriod]) -> [[NWSForecastPeriod]] {
        var grouped: [[NWSForecastPeriod]] = []
        var currentGroup: [NWSForecastPeriod] = []
        
        for period in periods {
            if currentGroup.isEmpty {
                currentGroup.append(period)
            } else if (currentGroup.last!.isDaytime && !period.isDaytime) || 
                      (!currentGroup.last!.isDaytime && period.isDaytime && period.number % 2 == 1) {
                currentGroup.append(period)
                if currentGroup.count == 2 || (!currentGroup[0].isDaytime && currentGroup.count == 1) {
                    grouped.append(currentGroup)
                    currentGroup = []
                }
            } else {
                grouped.append(currentGroup)
                currentGroup = [period]
            }
        }
        
        if !currentGroup.isEmpty {
            grouped.append(currentGroup)
        }
        
        return grouped
    }
    
    // Convert NWS periods to our daily forecast model
    private func convertToDaily(_ periods: [NWSForecastPeriod], unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> DailyForecast {
        let dayPeriod = periods.first(where: { $0.isDaytime }) ?? periods.first!
        let nightPeriod = periods.first(where: { !$0.isDaytime })
        
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: dayPeriod.startTime) ?? Date()
        
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "E"
        let fullDayFormatter = DateFormatter()
        fullDayFormatter.dateFormat = "EEEE"
        
        let tempHigh = Double(dayPeriod.temperature)
        let tempLow = nightPeriod != nil ? Double(nightPeriod.temperature) : (tempHigh - 10) // Fallback
        
        // Extract wind speed as a number
        let windSpeedString = dayPeriod.windSpeed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let windSpeed = Double(windSpeedString) ?? 0
        
        // Convert temperature if needed
        let adjustedHigh = dayPeriod.temperatureUnit == "F" && unit == .celsius ? (tempHigh - 32) * 5/9 : tempHigh
        let adjustedLow = dayPeriod.temperatureUnit == "F" && unit == .celsius ? (tempLow - 32) * 5/9 : tempLow
        
        return DailyForecast(
            id: "day-\(dayPeriod.number)",
            day: dayNameFormatter.string(from: date),
            fullDay: fullDayFormatter.string(from: date),
            date: date,
            tempHigh: adjustedHigh,
            tempLow: adjustedLow,
            precipitation: Precipitation(chance: getCombinedPrecipChance(dayPeriod, nightPeriod)),
            uvIndex: getUVIndex(dayPeriod.detailedForecast),
            wind: Wind(speed: windSpeed, direction: dayPeriod.windDirection),
            icon: mapNWSIconToAppIcon(dayPeriod.icon),
            detailedForecast: dayPeriod.detailedForecast,
            shortForecast: dayPeriod.shortForecast,
            humidity: getHumidityEstimate(dayPeriod.detailedForecast),
            dewpoint: nil, // NWS doesn't provide dewpoint in basic forecast
            pressure: nil, // NWS doesn't provide pressure in basic forecast
            skyCover: getSkyCoverEstimate(dayPeriod.shortForecast)
        )
    }
    
    // Convert NWS hourly period to our hourly forecast model
    private func convertToHourly(_ period: NWSForecastPeriod, index: Int, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> HourlyForecast {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: period.startTime) ?? Date()
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "ha"
        
        let temp = Double(period.temperature)
        let adjustedTemp = period.temperatureUnit == "F" && unit == .celsius ? (temp - 32) * 5/9 : temp
        
        // Extract wind speed as a number
        let windSpeedString = period.windSpeed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let windSpeed = Double(windSpeedString) ?? 0
        
        return HourlyForecast(
            id: "hour-\(index)",
            time: timeFormatter.string(from: date).lowercased(),
            temperature: adjustedTemp,
            icon: mapNWSIconToAppIcon(period.icon),
            shortForecast: period.shortForecast,
            windSpeed: windSpeed,
            windDirection: period.windDirection,
            isDaytime: period.isDaytime
        )
    }
    
    // Convert NWS alert to our weather alert model
    private func convertToWeatherAlert(_ alert: NWSAlertProperties) -> WeatherAlert {
        let dateFormatter = ISO8601DateFormatter()
        
        // Parse dates
        let startDate = dateFormatter.date(from: alert.effective) ?? Date()
        let endDate = dateFormatter.date(from: alert.expires)
        
        return WeatherAlert(
            id: alert.id,
            headline: alert.headline ?? alert.event,
            description: alert.description,
            severity: mapNWSSeverity(alert.severity),
            event: alert.event,
            start: startDate,
            end: endDate
        )
    }
    
    // Map NWS icon URLs to our app icons
    private func mapNWSIconToAppIcon(_ iconURL: String) -> String {
        if iconURL.contains("sunny") || iconURL.contains("clear") {
            return iconURL.contains("night") ? "clear-night" : "clear-day"
        } else if iconURL.contains("cloudy") {
            if iconURL.contains("partly") {
                return iconURL.contains("night") ? "partly-cloudy-night" : "partly-cloudy-day"
            } else {
                return "cloudy"
            }
        } else if iconURL.contains("rain") {
            return "rain"
        } else if iconURL.contains("snow") {
            return "snow"
        } else if iconURL.contains("sleet") || iconURL.contains("ice") {
            return "sleet"
        } else if iconURL.contains("fog") {
            return "fog"
        } else if iconURL.contains("wind") {
            return "wind"
        }
        
        return "cloudy" // Default fallback
    }
    
    // Map NWS severity to our severity levels
    private func mapNWSSeverity(_ severity: String) -> String {
        switch severity.lowercased() {
        case "extreme":
            return "extreme"
        case "severe":
            return "severe"
        case "moderate":
            return "moderate"
        default:
            return "minor"
        }
    }
    
    // Extract UV index from forecast text (NWS doesn't provide it directly)
    private func getUVIndex(_ detailedForecast: String) -> Int {
        if detailedForecast.contains("UV index") {
            let components = detailedForecast.components(separatedBy: "UV index")
            if components.count > 1 {
                let afterUV = components[1]
                let numberStr = afterUV.components(separatedBy: CharacterSet.decimalDigits.inverted)[0]
                return Int(numberStr) ?? 0
            }
        }
        
        // Estimate based on cloud cover and forecast text
        if detailedForecast.contains("sunny") {
            return 8
        } else if detailedForecast.contains("partly sunny") {
            return 5
        } else if detailedForecast.contains("cloudy") {
            return 2
        }
        
        return 3 // Default moderate value
    }
    
    // Estimate humidity from forecast text
    private func getHumidityEstimate(_ detailedForecast: String) -> Double? {
        if detailedForecast.contains("humidity") {
            let components = detailedForecast.components(separatedBy: "humidity")
            if components.count > 1 {
                let beforeHumidity = components[0].components(separatedBy: " ").last ?? ""
                return Double(beforeHumidity)
            }
        }
        
        // Rough estimate based on conditions
        if detailedForecast.contains("rain") || detailedForecast.contains("shower") {
            return 85.0
        } else if detailedForecast.contains("fog") || detailedForecast.contains("mist") {
            return 95.0
        } else if detailedForecast.contains("humid") {
            return 80.0
        } else if detailedForecast.contains("dry") {
            return 30.0
        }
        
        return 60.0 // Default value
    }
    
    // Estimate sky cover from forecast text
    private func getSkyCoverEstimate(_ shortForecast: String) -> Double? {
        if shortForecast.contains("Clear") || shortForecast.contains("Sunny") {
            return 0.0
        } else if shortForecast.contains("Mostly Clear") || shortForecast.contains("Mostly Sunny") {
            return 25.0
        } else if shortForecast.contains("Partly Cloudy") || shortForecast.contains("Partly Sunny") {
            return 50.0
        } else if shortForecast.contains("Mostly Cloudy") {
            return 75.0
        } else if shortForecast.contains("Cloudy") {
            return 100.0
        }
        
        return 50.0 // Default value
    }
    
    // Extract precipitation chance from forecast text if available
    private func extractPrecipChance(from detailedForecast: String) -> Double {
        // Look for patterns like "40 percent chance of rain" or "chance of rain 40 percent"
        let regex1 = try? NSRegularExpression(pattern: "(\\d+)\\s*percent\\s*chance", options: [.caseInsensitive])
        let regex2 = try? NSRegularExpression(pattern: "chance\\s*of\\s*[\\w\\s]+\\s*(\\d+)\\s*percent", options: [.caseInsensitive])
        
        if let regex = regex1, let match = regex.firstMatch(in: detailedForecast, range: NSRange(detailedForecast.startIndex..., in: detailedForecast)) {
            if let percentRange = Range(match.range(at: 1), in: detailedForecast) {
                if let percent = Double(detailedForecast[percentRange]) {
                    return percent
                }
            }
        }
        
        if let regex = regex2, let match = regex.firstMatch(in: detailedForecast, range: NSRange(detailedForecast.startIndex..., in: detailedForecast)) {
            if let percentRange = Range(match.range(at: 1), in: detailedForecast) {
                if let percent = Double(detailedForecast[percentRange]) {
                    return percent
                }
            }
        }
        
        // Fallback to condition-based estimates
        if detailedForecast.contains("rain") || detailedForecast.contains("shower") {
            if detailedForecast.contains("likely") {
                return 70.0
            } else if detailedForecast.contains("possible") {
                return 40.0
            } else if detailedForecast.contains("slight chance") {
                return 20.0
            }
        }
        
        return 0.0 // Default
    }
    
    // Combine day and night precipitation chances
    private func getCombinedPrecipChance(_ dayPeriod: NWSForecastPeriod, _ nightPeriod: NWSForecastPeriod?) -> Double {
        // First try to get from probability field
        var dayChance: Double = dayPeriod.probabilityOfPrecipitation?.value.map { Double($0) } ?? 0.0
        var nightChance: Double = nightPeriod?.probabilityOfPrecipitation?.value.map { Double($0) } ?? 0.0
        
        // If not available, try to extract from text
        if dayChance == 0 {
            dayChance = extractPrecipChance(from: dayPeriod.detailedForecast)
        }
        
        if nightChance == 0 && nightPeriod != nil {
            nightChance = extractPrecipChance(from: nightPeriod!.detailedForecast)
        }
        
        // Return the maximum of the two periods
        return max(dayChance, nightChance)
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
    static func createWeatherAPI(for location: CLLocationCoordinate2D) -> WeatherAPIProtocol {
        if LocationUtils.isLocationInUS(location) {
            return NWSWeatherAPI()
        } else {
            return OpenWeatherMapAPI(apiKey: ApiKeyManager.shared.openWeatherMapApiKey)
        }
    }
    
    static func createService(type: WeatherServiceType) -> WeatherAPIProtocol {
        switch type {
        case .openWeatherMap:
            return OpenWeatherMapAPI(apiKey: ApiKeyManager.shared.openWeatherMapApiKey)
        case .nationalWeatherService:
            return NWSWeatherAPI()
        }
    }
    
    enum WeatherServiceType {
        case openWeatherMap
        case nationalWeatherService
    }
}

// MARK: - API Key Management
class ApiKeyManager {
    static let shared = ApiKeyManager()
    
    private let openWeatherMapApiKeyKey = "openWeatherMapApiKey"
    private let keychainService = "com.weatherapp.apikeys"
    
    private init() {
        // Initialize with default API keys if needed
        if openWeatherMapApiKey.isEmpty {
            // For development, set a default key
            #if DEBUG
            setOpenWeatherMapApiKey("YOUR_DEVELOPMENT_KEY")
            #endif
        }
    }
    
    var openWeatherMapApiKey: String {
        get {
            // Try to get from keychain
            if let data = KeychainWrapper.standard.data(forKey: openWeatherMapApiKeyKey, service: keychainService),
               let key = String(data: data, encoding: .utf8) {
                return key
            }
            
            // Fall back to UserDefaults if keychain fails
            return UserDefaults.standard.string(forKey: openWeatherMapApiKeyKey) ?? ""
        }
    }
    
    func setOpenWeatherMapApiKey(_ key: String) {
        // Store in keychain
        KeychainWrapper.standard.set(Data(key.utf8), forKey: openWeatherMapApiKeyKey, service: keychainService)
        
        // Backup in UserDefaults
        UserDefaults.standard.set(key, forKey: openWeatherMapApiKeyKey)
    }
}

// MARK: - Location Utilities
class LocationUtils {
    static func isLocationInUS(_ location: CLLocationCoordinate2D) -> Bool {
        // Approximate bounding box for the continental US
        // Note: This is a simplified approach, might not be accurate for all edge cases
        let usMinLat = 24.396308
        let usMaxLat = 49.384358
        let usMinLon = -125.0
        let usMaxLon = -66.93457
        
        // Alaska
        let akMinLat = 51.0
        let akMaxLat = 71.5
        let akMinLon = -180.0
        let akMaxLon = -129.0
        
        // Hawaii
        let hiMinLat = 18.0
        let hiMaxLat = 23.0
        let hiMinLon = -160.0
        let hiMaxLon = -154.0
        
        // Check if the location is within the continental US
        let inContinentalUS = location.latitude >= usMinLat && location.latitude <= usMaxLat &&
                              location.longitude >= usMinLon && location.longitude <= usMaxLon
        
        // Check if the location is within Alaska
        let inAlaska = location.latitude >= akMinLat && location.latitude <= akMaxLat &&
                       location.longitude >= akMinLon && location.longitude <= akMaxLon
        
        // Check if the location is within Hawaii
        let inHawaii = location.latitude >= hiMinLat && location.latitude <= hiMaxLat &&
                       location.longitude >= hiMinLon && location.longitude <= hiMaxLon
        
        return inContinentalUS || inAlaska || inHawaii
    }
    
    // For more accurate results, a reverse geocoding approach could be used
    static func isLocationInUSUsingGeocoder(_ location: CLLocationCoordinate2D) -> AnyPublisher<Bool, Error> {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        return Future<Bool, Error> { promise in
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                if let countryCode = placemarks?.first?.isoCountryCode {
                    promise(.success(countryCode == "US"))
                } else {
                    // Fall back to bounding box method if geocoding fails
                    promise(.success(self.isLocationInUS(location)))
                }
            }
        }.eraseToAnyPublisher()
    }
}

// MARK: - Simple Keychain Wrapper for API Keys
class KeychainWrapper {
    static let standard = KeychainWrapper()
    
    private init() {}
    
    func set(_ data: Data, forKey key: String, service: String) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecValueData as String: data
        ] as [String: Any]
        
        // First try to delete any existing key
        SecItemDelete(query as CFDictionary)
        
        // Then add the new key
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func data(forKey key: String, service: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess ? result as? Data : nil
    }
}
