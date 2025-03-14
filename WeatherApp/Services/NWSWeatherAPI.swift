import Foundation
import Combine
import CoreLocation

/// National Weather Service API Implementation
class NWSWeatherAPI: WeatherAPIProtocol {
    private let baseURL = "https://api.weather.gov"
    private let decoder: JSONDecoder
    private let dateFormatter = DateFormatter()
    private let timeFormatter = DateFormatter()
    private let dayFormatter = DateFormatter()
    private let fullDayFormatter = DateFormatter()
    
    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        timeFormatter.dateFormat = "ha"
        dayFormatter.dateFormat = "E"
        fullDayFormatter.dateFormat = "EEEE"
    }
    
    func fetchWeatherData(for location: CLLocationCoordinate2D, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError> {
        return getGridPoints(for: location)
            .flatMap { gridInfo -> AnyPublisher<(NWSPointProperties, [NWSForecastPeriod], [NWSForecastPeriod]), WeatherError> in
                // Get both daily and hourly forecasts in parallel
                return Publishers.Zip3(
                    Just(gridInfo).setFailureType(to: WeatherError.self),
                    self.getDailyForecast(from: gridInfo),
                    self.getHourlyForecast(from: gridInfo)
                ).eraseToAnyPublisher()
            }
            .flatMap { gridInfo, dailyPeriods, hourlyPeriods -> AnyPublisher<(NWSPointProperties, [NWSForecastPeriod], [NWSForecastPeriod], [WeatherAlert]), WeatherError> in
                // Get alerts
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
                // Convert NWS data to our app model
                let weatherData = self.convertToWeatherData(
                    gridInfo: gridInfo,
                    dailyPeriods: dailyPeriods,
                    hourlyPeriods: hourlyPeriods,
                    unit: unit
                )
                
                return APIResponse(weatherData: weatherData, alerts: alerts)
            }
            .mapError { error -> WeatherError in
                if let weatherError = error as? WeatherError {
                    return weatherError
                }
                return WeatherError.apiError("Unknown error: \(error.localizedDescription)")
            }
            .eraseToAnyPublisher()
    }
    
    func fetchWeatherData(for cityName: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<APIResponse, WeatherError> {
        // NWS doesn't support direct city lookup, so we need to geocode the city first
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
        .flatMap { location in
            self.fetchWeatherData(for: location, unit: unit)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    /// Get NWS grid points from lat/lon
    private func getGridPoints(for location: CLLocationCoordinate2D) -> AnyPublisher<NWSPointProperties, WeatherError> {
        let endpoint = "\(baseURL)/points/\(location.latitude),\(location.longitude)"
        guard let url = URL(string: endpoint) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("ios-weather-dashboard/1.0", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WeatherError.apiError("Invalid response")
                }
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw WeatherError.apiError("Server error: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: NWSPointsResponse.self, decoder: decoder)
            .mapError { error -> WeatherError in
                if let decodingError = error as? DecodingError {
                    return WeatherError.decodingError(decodingError)
                } else if let weatherError = error as? WeatherError {
                    return weatherError
                }
                return WeatherError.apiError(error.localizedDescription)
            }
            .map { $0.properties }
            .eraseToAnyPublisher()
    }
    
    /// Get daily forecast from grid points
    private func getDailyForecast(from gridInfo: NWSPointProperties) -> AnyPublisher<[NWSForecastPeriod], WeatherError> {
        guard let url = URL(string: gridInfo.forecast) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("ios-weather-dashboard/1.0", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WeatherError.apiError("Invalid response")
                }
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw WeatherError.apiError("Server error: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: NWSForecastResponse.self, decoder: decoder)
            .mapError { error -> WeatherError in
                if let decodingError = error as? DecodingError {
                    return WeatherError.decodingError(decodingError)
                } else if let weatherError = error as? WeatherError {
                    return weatherError
                }
                return WeatherError.apiError(error.localizedDescription)
            }
            .map { $0.properties.periods }
            .eraseToAnyPublisher()
    }
    
    /// Get hourly forecast from grid points
    private func getHourlyForecast(from gridInfo: NWSPointProperties) -> AnyPublisher<[NWSForecastPeriod], WeatherError> {
        guard let url = URL(string: gridInfo.forecastHourly) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("ios-weather-dashboard/1.0", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WeatherError.apiError("Invalid response")
                }
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw WeatherError.apiError("Server error: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: NWSForecastResponse.self, decoder: decoder)
            .mapError { error -> WeatherError in
                if let decodingError = error as? DecodingError {
                    return WeatherError.decodingError(decodingError)
                } else if let weatherError = error as? WeatherError {
                    return weatherError
                }
                return WeatherError.apiError(error.localizedDescription)
            }
            .map { $0.properties.periods }
            .eraseToAnyPublisher()
    }
    
    /// Get weather alerts for the location
    private func getAlerts(for location: CLLocationCoordinate2D) -> AnyPublisher<[WeatherAlert], WeatherError> {
        let endpoint = "\(baseURL)/alerts/active?point=\(location.latitude),\(location.longitude)"
        guard let url = URL(string: endpoint) else {
            return Fail(error: WeatherError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("ios-weather-dashboard/1.0", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { WeatherError.networkError($0) }
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WeatherError.apiError("Invalid response")
                }
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw WeatherError.apiError("Server error: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: NWSAlertResponse.self, decoder: decoder)
            .mapError { error -> WeatherError in
                if let decodingError = error as? DecodingError {
                    return WeatherError.decodingError(decodingError)
                } else if let weatherError = error as? WeatherError {
                    return weatherError
                }
                return WeatherError.apiError(error.localizedDescription)
            }
            .map { response -> [WeatherAlert] in
                return response.features.map { feature in
                    return self.convertToWeatherAlert(feature.properties)
                }
            }
            .catch { error -> AnyPublisher<[WeatherAlert], WeatherError> in
                // If alerts endpoint fails, return an empty array rather than failing the whole request
                print("Warning: Alert fetching failed: \(error.localizedDescription)")
                return Just([]).setFailureType(to: WeatherError.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Data Conversion Methods
    
    /// Convert NWS data to our app's WeatherData model
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
        }
        
        // Set metadata
        let metadata = WeatherMetadata(
            office: gridInfo.gridId,
            gridX: String(gridInfo.gridX),
            gridY: String(gridInfo.gridY),
            timezone: gridInfo.timeZone ?? TimeZone.current.identifier,
            updated: dateFormatter.string(from: Date())
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
    
    /// Group day/night periods into single days
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
    
    /// Convert NWS periods to our daily forecast model
    private func convertToDaily(_ periods: [NWSForecastPeriod], unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> DailyForecast {
        let dayPeriod = periods.first(where: { $0.isDaytime }) ?? periods.first!
        let nightPeriod = periods.first(where: { !$0.isDaytime })
        
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: dayPeriod.startTime) ?? Date()
        
        let tempHigh = Double(dayPeriod.temperature)
        let tempLow = nightPeriod != nil ? Double(nightPeriod.temperature) : (tempHigh - 10) // Fallback
        
        // Convert if necessary
        let adjustedTempHigh = unit == .celsius && dayPeriod.temperatureUnit == "F" ? 
            (tempHigh - 32) * 5/9 : tempHigh
        let adjustedTempLow = unit == .celsius && dayPeriod.temperatureUnit == "F" ? 
            (tempLow - 32) * 5/9 : tempLow
        
        // Extract wind speed as a number
        let windSpeedString = dayPeriod.windSpeed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let windSpeed = Double(windSpeedString) ?? 0
        
        return DailyForecast(
            id: "day-\(dayPeriod.number)",
            day: dayFormatter.string(from: date),
            fullDay: fullDayFormatter.string(from: date),
            date: date,
            tempHigh: adjustedTempHigh,
            tempLow: adjustedTempLow,
            precipitation: Precipitation(chance: getCombinedPrecipChance(dayPeriod, nightPeriod)),
            uvIndex: getUVIndex(dayPeriod.detailedForecast),
            wind: Wind(speed: windSpeed, direction: dayPeriod.windDirection),
            icon: mapNWSIconToAppIcon(dayPeriod.icon),
            detailedForecast: dayPeriod.detailedForecast,
            shortForecast: dayPeriod.shortForecast,
            humidity: getHumidityEstimate(dayPeriod),
            dewpoint: nil, // NWS doesn't provide dewpoint in basic forecast
            pressure: nil, // NWS doesn't provide pressure in basic forecast
            skyCover: getSkyCoverEstimate(dayPeriod.shortForecast)
        )
    }
    
    /// Convert NWS hourly period to our hourly forecast model
    private func convertToHourly(_ period: NWSForecastPeriod, index: Int, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> HourlyForecast {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: period.startTime) ?? Date()
        
        let temp = Double(period.temperature)
        let adjustedTemp = unit == .celsius && period.temperatureUnit == "F" ? 
            (temp - 32) * 5/9 : temp
        
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
    
    /// Convert NWS alert to our weather alert model
    private func convertToWeatherAlert(_ alert: NWSAlertProperties) -> WeatherAlert {
        let dateFormatter = ISO8601DateFormatter()
        
        return WeatherAlert(
            id: alert.id,
            headline: alert.headline ?? alert.event,
            description: alert.description,
            severity: mapNWSSeverity(alert.severity),
            event: alert.event,
            start: dateFormatter.date(from: alert.effective) ?? Date(),
            end: dateFormatter.date(from: alert.expires)
        )
    }
    
    // MARK: - Helper Functions
    
    /// Map NWS icon URLs to our app icon names
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
    
    /// Map NWS severity to our severity levels
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
    
    /// Extract UV index from forecast text (NWS doesn't provide it directly)
    private func getUVIndex(_ detailedForecast: String) -> Int {
        if detailedForecast.contains("UV index") {
            let components = detailedForecast.components(separatedBy: "UV index")
            if components.count > 1 {
                let afterUV = components[1]
                let possibleNumberStrings = afterUV.components(separatedBy: CharacterSet.decimalDigits.inverted)
                if let firstNumberString = possibleNumberStrings.first(where: { !$0.isEmpty }) {
                    return Int(firstNumberString) ?? 0
                }
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
    
    /// Estimate humidity from forecast text or API response
    private func getHumidityEstimate(_ period: NWSForecastPeriod) -> Double? {
        if let relativeHumidity = period.relativeHumidity?.value {
            return Double(relativeHumidity)
        }
        
        // Estimate based on conditions
        let detailedForecast = period.detailedForecast
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
    
    /// Estimate sky cover from forecast text
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
    
    /// Estimate combined precipitation chance
    private func getCombinedPrecipChance(_ dayPeriod: NWSForecastPeriod, _ nightPeriod: NWSForecastPeriod?) -> Double {
        // Try to extract from the API response
        var dayChance = dayPeriod.probabilityOfPrecipitation?.value ?? 0
        var nightChance = nightPeriod?.probabilityOfPrecipitation?.value ?? 0
        
        // If not available, extract from text or use estimates
        if dayChance == 0 {
            dayChance = extractPrecipChance(from: dayPeriod.detailedForecast)
        }
        
        if dayChance == 0 {
            dayChance = estimatePrecipChance(from: dayPeriod.shortForecast)
        }
        
        if nightChance == 0 && nightPeriod != nil {
            nightChance = extractPrecipChance(from: nightPeriod!.detailedForecast)
        }
        
        if nightChance == 0 && nightPeriod != nil {
            nightChance = estimatePrecipChance(from: nightPeriod!.shortForecast)
        }
        
        return max(Double(dayChance), Double(nightChance))
    }
    
    /// Extract precipitation chance from text
    private func extractPrecipChance(from forecast: String) -> Int {
        let patterns = [
            "chance of precipitation is (\\d+)%",
            "(\\d+)% chance of precipitation",
            "(\\d+)% chance of rain",
            "(\\d+)% chance of snow"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: forecast, options: [], range: NSRange(forecast.startIndex..., in: forecast)) {
                if let percentRange = Range(match.range(at: 1), in: forecast),
                   let percent = Int(forecast[percentRange]) {
                    return percent
                }
            }
        }
        
        return 0
    }
    
    /// Estimate precipitation chance from short forecast description
    private func estimatePrecipChance(from shortForecast: String) -> Int {
        if shortForecast.contains("Rain") || shortForecast.contains("Showers") || shortForecast.contains("Thunderstorms") {
            if shortForecast.contains("Slight Chance") {
                return 20
            } else if shortForecast.contains("Chance") {
                return 40
            } else if shortForecast.contains("Likely") {
                return 70
            } else if shortForecast.contains("Definite") || shortForecast.contains("Heavy") {
                return 90
            } else {
                return 50
            }
        }
        
        return 0
    }
}
