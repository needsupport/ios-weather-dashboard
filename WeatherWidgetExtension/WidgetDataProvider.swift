import Foundation
import WidgetKit

// MARK: - Widget Data Provider
class WeatherWidgetDataProvider {
    static let shared = WeatherWidgetDataProvider()
    
    private let userDefaults: UserDefaults?
    private let weatherDataKey = "weatherWidgetData"
    
    private init() {
        // Initialize with app group container
        userDefaults = UserDefaults(suiteName: "group.com.weatherapp.widget")
    }
    
    func saveWidgetData(_ data: WeatherWidgetData) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            print("Failed to encode widget data")
            return
        }
        
        userDefaults?.set(encoded, forKey: weatherDataKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func loadWidgetData() -> WeatherWidgetData? {
        guard let data = userDefaults?.data(forKey: weatherDataKey),
              let widgetData = try? JSONDecoder().decode(WeatherWidgetData.self, from: data) else {
            return createPlaceholderData()
        }
        
        return widgetData
    }
    
    // Create placeholder data for widget preview and initial state
    func createPlaceholderData() -> WeatherWidgetData {
        let dailyForecasts = (0..<7).map { i in
            return DailyWidgetForecast(
                id: "day-\(i)",
                day: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][i % 7],
                highTemperature: Double(20 + i),
                lowTemperature: Double(10 + i),
                condition: ["Sunny", "Partly Cloudy", "Cloudy", "Rainy"][i % 4],
                iconName: ["sun", "cloud.sun", "cloud", "cloud.rain"][i % 4],
                precipitationChance: Double([0, 10, 30, 60][i % 4])
            )
        }
        
        return WeatherWidgetData(
            location: "San Francisco, CA",
            temperature: 22.0,
            temperatureUnit: "C",
            condition: "Partly Cloudy",
            iconName: "cloud.sun",
            highTemperature: 24.0,
            lowTemperature: 16.0,
            precipitationChance: 20.0,
            dailyForecasts: dailyForecasts,
            lastUpdated: Date()
        )
    }
}

// MARK: - Widget Data Models
struct WeatherWidgetData: Codable {
    let location: String
    let temperature: Double
    let temperatureUnit: String
    let condition: String
    let iconName: String
    let highTemperature: Double
    let lowTemperature: Double
    let precipitationChance: Double
    let dailyForecasts: [DailyWidgetForecast]
    let lastUpdated: Date
    
    var temperatureString: String {
        return "\(Int(round(temperature)))°\(temperatureUnit)"
    }
    
    var highTempString: String {
        return "\(Int(round(highTemperature)))°"
    }
    
    var lowTempString: String {
        return "\(Int(round(lowTemperature)))°"
    }
}

struct DailyWidgetForecast: Codable, Identifiable {
    var id: String
    let day: String
    let highTemperature: Double
    let lowTemperature: Double
    let condition: String
    let iconName: String
    let precipitationChance: Double
    
    var highTempString: String {
        return "\(Int(round(highTemperature)))°"
    }
    
    var lowTempString: String {
        return "\(Int(round(lowTemperature)))°"
    }
}

// MARK: - Helper Functions
extension WeatherWidgetDataProvider {
    // Get system icon name from our icon name
    func getSystemIcon(from weatherCode: String) -> String {
        switch weatherCode {
        case "clear-day": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "partly-cloudy-day": return "cloud.sun.fill"
        case "partly-cloudy-night": return "cloud.moon.fill"
        case "cloudy": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "sleet": return "cloud.sleet.fill"
        case "snow": return "cloud.snow.fill"
        case "wind": return "wind"
        case "fog": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
    
    // Generate background gradient based on weather condition
    func weatherBackgroundGradient(for condition: String, isDaytime: Bool) -> (leading: Color, trailing: Color) {
        var colors: (Color, Color)
        
        if condition.contains("clear") || condition.contains("sunny") {
            colors = isDaytime ? (Color.blue, Color.cyan) : (Color.indigo, Color.purple)
        } else if condition.contains("cloud") {
            colors = isDaytime ? (Color.gray, Color.blue.opacity(0.7)) : (Color.gray, Color.indigo.opacity(0.7))
        } else if condition.contains("rain") {
            colors = (Color.gray, Color.blue)
        } else if condition.contains("snow") {
            colors = (Color.gray.opacity(0.8), Color.white.opacity(0.9))
        } else {
            colors = isDaytime ? (Color.blue, Color.purple.opacity(0.7)) : (Color.indigo, Color.purple)
        }
        
        return colors
    }
    
    // Check if data is stale and needs refresh
    func isDataStale(_ widgetData: WeatherWidgetData) -> Bool {
        // Consider data stale if older than 1 hour
        let staleThreshold: TimeInterval = 60 * 60 // 1 hour in seconds
        let timeSinceUpdate = Date().timeIntervalSince(widgetData.lastUpdated)
        
        return timeSinceUpdate > staleThreshold
    }
}

// MARK: - Color extension for Widget
import SwiftUI

extension Color {
    static let weatherBlue = Color(red: 0.4, green: 0.8, blue: 1.0)
    static let weatherYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let weatherGray = Color(red: 0.6, green: 0.6, blue: 0.6)
}
