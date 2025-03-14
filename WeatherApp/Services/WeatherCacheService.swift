import Foundation

struct WeatherCache: Codable {
    let weatherData: WeatherData
    let hourlyExpiration: Date
    let dailyExpiration: Date
    let locationName: String
}

class WeatherCacheService {
    private let userDefaults = UserDefaults.standard
    private let dailyCacheKey = "weatherDailyCache"
    private let hourlyCacheKey = "weatherHourlyCache"
    
    // Cache durations
    private let hourlyExpirationDuration: TimeInterval = 3600 // 1 hour
    private let dailyExpirationDuration: TimeInterval = 10800 // 3 hours
    
    func save(weatherData: WeatherData, for location: String) {
        let hourlyExpiration = Date().addingTimeInterval(hourlyExpirationDuration)
        let dailyExpiration = Date().addingTimeInterval(dailyExpirationDuration)
        
        let cache = WeatherCache(
            weatherData: weatherData,
            hourlyExpiration: hourlyExpiration,
            dailyExpiration: dailyExpiration,
            locationName: location
        )
        
        if let encodedData = try? JSONEncoder().encode(cache) {
            let cacheKey = getCacheKey(for: location)
            userDefaults.set(encodedData, forKey: cacheKey)
        }
    }
    
    func loadCachedData(for location: String) -> WeatherData? {
        let cacheKey = getCacheKey(for: location)
        
        guard let encodedData = userDefaults.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(WeatherCache.self, from: encodedData) else {
            return nil
        }
        
        let now = Date()
        let hourlyDataValid = cache.hourlyExpiration > now
        let dailyDataValid = cache.dailyExpiration > now
        
        if !hourlyDataValid && !dailyDataValid {
            // Cache completely expired, remove it
            userDefaults.removeObject(forKey: cacheKey)
            return nil
        }
        
        // Create a modified copy of weatherData with potentially expired hourly data removed
        var weatherData = cache.weatherData
        if !hourlyDataValid {
            weatherData.hourly = []
        }
        
        return weatherData
    }
    
    func clearCache(for location: String? = nil) {
        if let location = location {
            let cacheKey = getCacheKey(for: location)
            userDefaults.removeObject(forKey: cacheKey)
        } else {
            // Clear all caches
            let allKeys = userDefaults.dictionaryRepresentation().keys
            for key in allKeys where key.hasPrefix("weatherCache_") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    private func getCacheKey(for location: String) -> String {
        return "weatherCache_\(location.replacingOccurrences(of: " ", with: "_").lowercased())"
    }
}
