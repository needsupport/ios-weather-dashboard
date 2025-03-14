import WidgetKit
import SwiftUI
import CoreData

/// Provides data for weather widgets with CoreData integration
class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    
    private let coreDataManager = CoreDataManager.shared
    
    private init() {}
    
    /// Get weather data for widgets
    /// - Parameter completion: Callback with widget data or nil if not available
    func getWidgetData(completion: @escaping (WeatherWidgetData?) -> Void) {
        // 1. Load saved locations from CoreData
        coreDataManager.fetchAllLocations()
            .sink(
                receiveCompletion: { completionStatus in
                    if case .failure(let error) = completionStatus {
                        print("Error fetching locations for widget: \(error.localizedDescription)")
                        completion(nil)
                    }
                },
                receiveValue: { [weak self] locations in
                    guard let self = self else { return }
                    
                    // 2. Determine which location to use (primary/favorite/first)
                    let locationToUse = self.determineWidgetLocation(from: locations)
                    
                    if let locationId = locationToUse?.id {
                        // 3. Get weather data for selected location
                        self.fetchWidgetDataForLocation(locationId: locationId, completion: completion)
                    } else {
                        // No valid location
                        completion(nil)
                    }
                }
            )
    }
    
    /// Determine which location to use for widget
    /// - Parameter locations: Available locations
    /// - Returns: Selected location or nil if no locations
    private func determineWidgetLocation(from locations: [LocationInfo]) -> LocationInfo? {
        // Priority:
        // 1. Favorite location
        // 2. Most recently updated
        // 3. First in list
        
        if let favoriteLocation = locations.first(where: { $0.isFavorite }) {
            return favoriteLocation
        } else if let mostRecentLocation = locations.max(by: { $0.lastUpdated < $1.lastUpdated }) {
            return mostRecentLocation
        } else {
            return locations.first
        }
    }
    
    /// Fetch weather data for a specific location
    /// - Parameters:
    ///   - locationId: ID of the location to fetch data for
    ///   - completion: Callback with widget data or nil if not available
    private func fetchWidgetDataForLocation(locationId: String, completion: @escaping (WeatherWidgetData?) -> Void) {
        coreDataManager.fetchWeatherData(for: locationId)
            .sink(
                receiveCompletion: { completionStatus in
                    if case .failure(let error) = completionStatus {
                        print("Error fetching weather data for widget: \(error.localizedDescription)")
                        completion(nil)
                    }
                },
                receiveValue: { weatherData in
                    guard let weatherData = weatherData else {
                        completion(nil)
                        return
                    }
                    
                    // Convert to widget data format
                    let widgetData = self.convertToWidgetData(weatherData)
                    completion(widgetData)
                }
            )
    }
    
    /// Convert app weather data to widget data
    /// - Parameter weatherData: App weather data model
    /// - Returns: Widget data model
    private func convertToWidgetData(_ weatherData: WeatherData) -> WeatherWidgetData {
        // Extract current conditions from first daily forecast
        let currentForecast = weatherData.daily.first
        let dailyForecasts = weatherData.daily.prefix(7).map { forecast in
            return DailyWidgetForecast(
                id: forecast.id,
                day: forecast.day,
                highTemperature: forecast.tempHigh,
                lowTemperature: forecast.tempLow,
                condition: forecast.shortForecast,
                iconName: forecast.icon,
                precipitationChance: forecast.precipitation.chance
            )
        }
        
        // Create widget data model
        return WeatherWidgetData(
            location: weatherData.location,
            temperature: currentForecast?.tempHigh ?? 0,
            temperatureUnit: "°F",  // Get from user preferences
            condition: currentForecast?.shortForecast ?? "Unknown",
            iconName: currentForecast?.icon ?? "cloud",
            highTemperature: currentForecast?.tempHigh ?? 0,
            lowTemperature: currentForecast?.tempLow ?? 0,
            precipitationChance: currentForecast?.precipitation.chance ?? 0,
            dailyForecasts: Array(dailyForecasts),
            lastUpdated: Date()
        )
    }
}

/// Data model for widgets
struct WeatherWidgetData {
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
        return "\(Int(round(temperature)))\(temperatureUnit)"
    }
    
    var highTempString: String {
        return "\(Int(round(highTemperature)))°"
    }
    
    var lowTempString: String {
        return "\(Int(round(lowTemperature)))°"
    }
}

/// Data model for daily forecasts in widgets
struct DailyWidgetForecast: Identifiable {
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
