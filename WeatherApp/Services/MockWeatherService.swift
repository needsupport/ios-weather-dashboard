import Foundation
import Combine
import CoreLocation
import GameKit

// MARK: - Mock Service for Development
class MockWeatherService: WeatherServiceProtocol {
    // Flag to control error simulation
    var shouldSimulateError = false
    var simulatedError: WeatherError = .networkError(NSError(domain: "MockService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated network error"]))
    
    // Delay in seconds to simulate network latency
    var simulatedDelay: Double = 1.0
    
    func fetchWeather(for coordinates: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error> {
        // Simulate error if needed
        if shouldSimulateError {
            return Fail(error: simulatedError)
                .delay(for: .seconds(simulatedDelay), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
        }
        
        // Generate mock data
        return Just((createMockWeatherData(forCoordinates: coordinates), createMockAlerts()))
            .delay(for: .seconds(simulatedDelay), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Mock Data Generation
    
    private func createMockWeatherData(forCoordinates coordinates: String) -> WeatherData {
        var weatherData = WeatherData()
        
        // Set location name based on coordinates
        let components = coordinates.split(separator: ",")
        if components.count == 2, 
           let lat = Double(components[0]), 
           let lon = Double(components[1]) {
            // Set location based on approximate coordinates
            if (37.7...37.8).contains(lat) && (-122.5...(-122.3)).contains(lon) {
                weatherData.location = "San Francisco, CA"
            } else if (40.7...40.8).contains(lat) && (-74.1...(-73.9)).contains(lon) {
                weatherData.location = "New York, NY"
            } else if (41.8...41.9).contains(lat) && (-87.7...(-87.5)).contains(lon) {
                weatherData.location = "Chicago, IL"
            } else if (34.0...34.1).contains(lat) && (-118.3...(-118.1)).contains(lon) {
                weatherData.location = "Los Angeles, CA"
            } else {
                weatherData.location = "Custom Location"
            }
        } else {
            weatherData.location = "Unknown Location"
        }
        
        // Generate daily forecasts
        let calendar = Calendar.current
        let today = Date()
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"
        
        let fullDayFormatter = DateFormatter()
        fullDayFormatter.dateFormat = "EEEE"
        
        // Use a seed based on location for consistent but varied weather
        let locationSeed = weatherData.location.hash
        var rng = SeededRandomNumberGenerator(seed: UInt64(bitPattern: Int64(locationSeed)))
        
        // Base temperature and conditions affected by location
        let baseHighTemp = (20.0 + Double(abs(locationSeed) % 10)) // 20-30°C base high
        let baseLowTemp = (baseHighTemp - 10.0) // 10-20°C base low
        
        // Weather patterns - more varied
        let weatherPatterns = [
            // Sunny pattern
            (
                icons: ["sun", "sun", "cloud.sun", "sun", "sun", "cloud.sun", "sun"],
                shortForecasts: ["Sunny", "Sunny", "Partly Cloudy", "Sunny", "Sunny", "Partly Cloudy", "Sunny"],
                tempAdjustments: [0.0, 1.0, -0.5, 1.5, 2.0, 0.0, 1.0],
                precipChances: [0.0, 5.0, 10.0, 5.0, 0.0, 15.0, 5.0]
            ),
            // Rainy pattern
            (
                icons: ["cloud", "cloud.rain", "cloud.rain", "cloud.rain", "cloud.drizzle", "cloud", "cloud.sun"],
                shortForecasts: ["Cloudy", "Rain", "Rain", "Heavy Rain", "Light Rain", "Cloudy", "Partly Cloudy"],
                tempAdjustments: [-2.0, -4.0, -3.0, -5.0, -2.0, -1.0, 0.0],
                precipChances: [30.0, 80.0, 90.0, 100.0, 70.0, 40.0, 20.0]
            ),
            // Mixed pattern
            (
                icons: ["cloud.sun", "cloud", "cloud.rain", "cloud.sun", "sun", "cloud", "cloud.rain"],
                shortForecasts: ["Partly Cloudy", "Cloudy", "Scattered Showers", "Partly Cloudy", "Sunny", "Cloudy", "Scattered Showers"],
                tempAdjustments: [-1.0, -2.0, -3.0, -1.0, 0.0, -2.0, -3.0],
                precipChances: [20.0, 40.0, 60.0, 30.0, 10.0, 50.0, 70.0]
            ),
            // Hot pattern
            (
                icons: ["sun", "sun", "sun", "sun.max", "sun.max", "sun", "cloud.sun"],
                shortForecasts: ["Sunny", "Hot", "Hot", "Very Hot", "Very Hot", "Hot", "Warm"],
                tempAdjustments: [2.0, 3.0, 4.0, 5.0, 5.0, 3.0, 1.0],
                precipChances: [0.0, 0.0, 5.0, 10.0, 20.0, 5.0, 10.0]
            ),
            // Cold pattern
            (
                icons: ["cloud", "snow", "snow", "cloud.snow", "cloud", "cloud.snow", "cloud"],
                shortForecasts: ["Cold", "Snow", "Snow", "Heavy Snow", "Cold", "Light Snow", "Cold"],
                tempAdjustments: [-8.0, -10.0, -12.0, -15.0, -10.0, -12.0, -8.0],
                precipChances: [20.0, 70.0, 80.0, 90.0, 40.0, 60.0, 30.0]
            )
        ]
        
        // Select a weather pattern based on location seed
        let patternIndex = abs(locationSeed) % weatherPatterns.count
        let selectedPattern = weatherPatterns[patternIndex]
        
        // Create 7 days of forecasts
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                // Add some daily variation with randomness
                let randomTempAdjustment = Double.random(in: -1.5...1.5, using: &rng)
                let highTemp = baseHighTemp + selectedPattern.tempAdjustments[i] + randomTempAdjustment
                let lowTemp = baseLowTemp + selectedPattern.tempAdjustments[i] * 0.7 + randomTempAdjustment * 0.5
                
                // Adjust precipitation for realism
                let precipChance = min(max(selectedPattern.precipChances[i] + Double.random(in: -10.0...10.0, using: &rng), 0), 100)
                
                // Atmospheric values
                let humidity = Double.random(in: 30...90, using: &rng)
                let windSpeed = Double.random(in: 5...25, using: &rng)
                let windDirections = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                let windDirection = windDirections[Int.random(in: 0..<windDirections.count, using: &rng)]
                let uvIndex = Int.random(in: 0...11, using: &rng)
                let pressure = Double.random(in: 980...1030, using: &rng)
                let skyCover = precipChance * 0.8 + Double.random(in: 0...20, using: &rng)
                
                // Create the forecast
                let forecast = DailyForecast(
                    id: "day-\(i)",
                    day: dayFormatter.string(from: date),
                    fullDay: fullDayFormatter.string(from: date),
                    date: date,
                    tempHigh: highTemp,
                    tempLow: lowTemp,
                    precipitation: Precipitation(chance: precipChance),
                    uvIndex: uvIndex,
                    wind: Wind(speed: windSpeed, direction: windDirection),
                    icon: selectedPattern.icons[i],
                    detailedForecast: createDetailedForecast(shortForecast: selectedPattern.shortForecasts[i], highTemp: highTemp, lowTemp: lowTemp, precipChance: precipChance, date: date),
                    shortForecast: selectedPattern.shortForecasts[i],
                    humidity: humidity,
                    dewpoint: lowTemp - Double.random(in: 0...5, using: &rng),
                    pressure: pressure,
                    skyCover: skyCover
                )
                
                weatherData.daily.append(forecast)
            }
        }
        
        // Generate hourly forecasts for the next 24 hours
        let hourlyFormatter = DateFormatter()
        hourlyFormatter.dateFormat = "ha"
        
        for i in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: i, to: today) {
                let hour = calendar.component(.hour, from: date)
                let isDaytime = hour >= 6 && hour < 18
                
                // Determine which daily forecast this hour belongs to
                let dayOffset = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                let dayIndex = min(dayOffset, weatherData.daily.count - 1)
                
                // Base temperatures on daily forecast with diurnal variation
                let dayForecast = weatherData.daily[dayIndex]
                let progress = isDaytime ? Double(hour - 6) / 12.0 : (hour < 6 ? 0.0 : 1.0)
                
                // Temperature varies throughout the day
                let hourTemp: Double
                if isDaytime {
                    // Morning to afternoon temperature curve
                    hourTemp = dayForecast.tempLow + (dayForecast.tempHigh - dayForecast.tempLow) * sin(Double.pi * progress / 2)
                } else {
                    // Evening to night temperature curve
                    let nightProgress = hour < 6 ? Double(hour + 6) / 12.0 : Double(hour - 18) / 12.0
                    let nextDayIndex = min(dayIndex + 1, weatherData.daily.count - 1)
                    let nextDayLow = weatherData.daily[nextDayIndex].tempLow
                    hourTemp = dayForecast.tempHigh - (dayForecast.tempHigh - nextDayLow) * nightProgress
                }
                
                // Weather conditions based on time of day and daily forecast
                let hourlyIcon: String
                let hourlyForecast: String
                
                if isDaytime {
                    if dayForecast.icon.contains("sun") {
                        hourlyIcon = hour < 10 ? "sun.haze" : "sun"
                        hourlyForecast = hour < 10 ? "Morning Sun" : "Sunny"
                    } else if dayForecast.icon.contains("rain") {
                        let isHeavy = dayForecast.precipitation.chance > 70
                        hourlyIcon = isHeavy ? "cloud.heavyrain" : "cloud.rain"
                        hourlyForecast = isHeavy ? "Heavy Rain" : "Rain"
                    } else if dayForecast.icon.contains("snow") {
                        hourlyIcon = "cloud.snow"
                        hourlyForecast = "Snow"
                    } else {
                        hourlyIcon = "cloud"
                        hourlyForecast = "Cloudy"
                    }
                } else {
                    // Night conditions
                    if dayForecast.icon.contains("sun") {
                        hourlyIcon = "moon"
                        hourlyForecast = "Clear"
                    } else if dayForecast.icon.contains("rain") {
                        hourlyIcon = "cloud.moon.rain"
                        hourlyForecast = "Rain"
                    } else if dayForecast.icon.contains("snow") {
                        hourlyIcon = "cloud.snow"
                        hourlyForecast = "Snow"
                    } else {
                        hourlyIcon = "cloud.moon"
                        hourlyForecast = "Cloudy"
                    }
                }
                
                let hourForecast = HourlyForecast(
                    id: "hour-\(i)",
                    time: hourlyFormatter.string(from: date).lowercased(),
                    temperature: hourTemp,
                    icon: hourlyIcon,
                    shortForecast: hourlyForecast,
                    windSpeed: dayForecast.wind.speed + Double.random(in: -3...3, using: &rng),
                    windDirection: dayForecast.wind.direction,
                    isDaytime: isDaytime
                )
                
                weatherData.hourly.append(hourForecast)
            }
        }
        
        return weatherData
    }
    
    private func createDetailedForecast(shortForecast: String, highTemp: Double, lowTemp: Double, precipChance: Double, date: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let day = dayFormatter.string(from: date)
        
        var detailed = "\(day): \(shortForecast) with a high of \(Int(round(highTemp)))°C and a low of \(Int(round(lowTemp)))°C. "
        
        if precipChance > 70 {
            detailed += "Very likely precipitation with a \(Int(precipChance))% chance. "
        } else if precipChance > 30 {
            detailed += "Chance of precipitation around \(Int(precipChance))%. "
        } else if precipChance > 10 {
            detailed += "Slight chance of precipitation (\(Int(precipChance))%). "
        } else {
            detailed += "Dry conditions expected. "
        }
        
        // Add some random additional information
        let additionalInfo = [
            "Winds may be gusty at times.",
            "Air quality is good.",
            "UV index is moderate, sun protection recommended.",
            "Visibility will be excellent.",
            "Humidity will be relatively high.",
            "Humidity will be comfortable.",
            "Expect clear skies overnight.",
            "Perfect weather for outdoor activities.",
            "Morning fog possible."
        ]
        
        let randomIndex = Int(abs(shortForecast.hash) % additionalInfo.count)
        detailed += additionalInfo[randomIndex]
        
        return detailed
    }
    
    private func createMockAlerts() -> [WeatherAlert] {
        // Randomly decide whether to include alerts (20% chance)
        let includeAlerts = Double.random(in: 0...1) < 0.2
        guard includeAlerts else { return [] }
        
        // If including alerts, generate 1-2 random alerts
        let alertCount = Int.random(in: 1...2)
        var alerts: [WeatherAlert] = []
        
        let alertTypes = [
            (
                event: "Severe Thunderstorm Warning",
                headline: "Severe Thunderstorm Warning issued for your area",
                description: "The National Weather Service has issued a Severe Thunderstorm Warning for your area. Damaging winds, large hail, and heavy rainfall are possible. Seek shelter in a sturdy building and stay away from windows.",
                severity: "severe"
            ),
            (
                event: "Flash Flood Watch",
                headline: "Flash Flood Watch in effect",
                description: "A Flash Flood Watch is in effect for your area. Heavy rainfall may lead to flash flooding in low-lying areas and near streams and creeks. Be prepared to move to higher ground if flooding occurs.",
                severity: "moderate"
            ),
            (
                event: "Excessive Heat Warning",
                headline: "Excessive Heat Warning issued",
                description: "An Excessive Heat Warning is in effect. Dangerously hot conditions with temperatures up to 40-45°C expected. Extreme heat can be life-threatening. Stay in air-conditioned spaces, drink plenty of fluids, and check on vulnerable individuals.",
                severity: "extreme"
            ),
            (
                event: "Winter Storm Warning",
                headline: "Winter Storm Warning issued for your area",
                description: "The National Weather Service has issued a Winter Storm Warning for your area. Heavy snow and blowing snow expected with accumulations of 20-30 cm. Travel could be very difficult to impossible. If you must travel, keep an extra flashlight, food, and water in your vehicle.",
                severity: "severe"
            ),
            (
                event: "Wind Advisory",
                headline: "Wind Advisory in effect",
                description: "A Wind Advisory is in effect for your area. Sustained winds of 30-40 km/h with gusts up to 60 km/h expected. Gusty winds could blow around unsecured objects. Tree limbs could be blown down and a few power outages may result.",
                severity: "moderate"
            )
        ]
        
        let now = Date()
        
        for i in 0..<alertCount {
            let alertTypeIndex = Int.random(in: 0..<alertTypes.count)
            let alertType = alertTypes[alertTypeIndex]
            
            let startDate = now.addingTimeInterval(Double.random(in: -3600...0)) // Start between 1 hour ago and now
            let endDate = now.addingTimeInterval(Double.random(in: 3600...86400)) // End between 1 hour and 1 day from now
            
            let alert = WeatherAlert(
                id: "alert-\(i)",
                headline: alertType.headline,
                description: alertType.description,
                severity: alertType.severity,
                event: alertType.event,
                start: startDate,
                end: endDate
            )
            
            alerts.append(alert)
        }
        
        return alerts
    }
}

// MARK: - Seeded Random Number Generator
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var rng: GKMersenneTwisterRandomSource
    
    init(seed: UInt64) {
        rng = GKMersenneTwisterRandomSource(seed: seed)
    }
    
    mutating func next() -> UInt64 {
        // GKRandom produces values in [INT32_MIN, INT32_MAX] range,
        // so we need multiple calls to generate UInt64
        let next1 = UInt64(bitPattern: Int64(rng.nextInt()))
        let next2 = UInt64(bitPattern: Int64(rng.nextInt()))
        let next3 = UInt64(bitPattern: Int64(rng.nextInt()))
        let next4 = UInt64(bitPattern: Int64(rng.nextInt()))
        
        return next1 ^ (next2 << 16) ^ (next3 << 32) ^ (next4 << 48)
    }
}

// Extension for random floating point with generator
extension Double {
    static func random(in range: ClosedRange<Double>, using generator: inout RandomNumberGenerator) -> Double {
        return range.lowerBound + (range.upperBound - range.lowerBound) * Double.random(in: 0...1, using: &generator)
    }
}