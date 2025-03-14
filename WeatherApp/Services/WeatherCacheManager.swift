import Foundation

/// Manager for caching weather data locally
class WeatherCacheManager {
    static let shared = WeatherCacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let weatherDataPrefix = "cached_weather_"
    private let weatherAlertsPrefix = "cached_alerts_"
    private let cacheExpirationPrefix = "cache_expiration_"
    
    // Cache expiration times
    private let hourlyDataExpirationTime: TimeInterval = 60 * 60 // 1 hour
    private let dailyDataExpirationTime: TimeInterval = 60 * 60 * 3 // 3 hours
    private let alertsExpirationTime: TimeInterval = 60 * 15 // 15 minutes
    
    private init() {}
    
    // MARK: - Weather Data Cache
    
    /// Save weather data to cache
    func saveWeatherData(_ data: WeatherData, for key: String) {
        guard let encodedData = try? JSONEncoder().encode(data) else {
            print("Failed to encode weather data for caching")
            return
        }
        
        userDefaults.set(encodedData, forKey: weatherDataPrefix + key)
        userDefaults.set(Date().timeIntervalSince1970, forKey: cacheExpirationPrefix + key)
        userDefaults.synchronize()
    }
    
    /// Get cached weather data if available and not expired
    func getWeatherData(for key: String, ignoreExpiration: Bool = false) -> WeatherData? {
        guard let cachedData = userDefaults.data(forKey: weatherDataPrefix + key) else {
            return nil
        }
        
        // Check if cache is expired
        if !ignoreExpiration {
            let expirationTimestamp = userDefaults.double(forKey: cacheExpirationPrefix + key)
            let currentTimestamp = Date().timeIntervalSince1970
            
            if currentTimestamp - expirationTimestamp > dailyDataExpirationTime {
                // Cache is expired
                return nil
            }
        }
        
        // Decode the cached data
        do {
            let weatherData = try JSONDecoder().decode(WeatherData.self, from: cachedData)
            return weatherData
        } catch {
            print("Failed to decode cached weather data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Weather Alerts Cache
    
    /// Save weather alerts to cache
    func saveWeatherAlerts(_ alerts: [WeatherAlert], for key: String) {
        guard let encodedData = try? JSONEncoder().encode(alerts) else {
            print("Failed to encode weather alerts for caching")
            return
        }
        
        userDefaults.set(encodedData, forKey: weatherAlertsPrefix + key)
        userDefaults.synchronize()
    }
    
    /// Get cached weather alerts if available and not expired
    func getWeatherAlerts(for key: String, ignoreExpiration: Bool = false) -> [WeatherAlert]? {
        guard let cachedData = userDefaults.data(forKey: weatherAlertsPrefix + key) else {
            return nil
        }
        
        // Check if cache is expired
        if !ignoreExpiration {
            let expirationTimestamp = userDefaults.double(forKey: cacheExpirationPrefix + key)
            let currentTimestamp = Date().timeIntervalSince1970
            
            if currentTimestamp - expirationTimestamp > alertsExpirationTime {
                // Cache is expired - for alerts we expire sooner
                return nil
            }
        }
        
        // Decode the cached data
        do {
            let alerts = try JSONDecoder().decode([WeatherAlert].self, from: cachedData)
            return alerts
        } catch {
            print("Failed to decode cached weather alerts: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached weather data
    func clearAllCache() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if key.hasPrefix(weatherDataPrefix) || 
               key.hasPrefix(weatherAlertsPrefix) || 
               key.hasPrefix(cacheExpirationPrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
        
        userDefaults.synchronize()
    }
    
    /// Clear cached data for a specific key
    func clearCache(for key: String) {
        userDefaults.removeObject(forKey: weatherDataPrefix + key)
        userDefaults.removeObject(forKey: weatherAlertsPrefix + key)
        userDefaults.removeObject(forKey: cacheExpirationPrefix + key)
        userDefaults.synchronize()
    }
    
    /// Check if cache is available for a key
    func hasCachedData(for key: String) -> Bool {
        return userDefaults.data(forKey: weatherDataPrefix + key) != nil
    }
    
    /// Get the age of cached data in seconds
    func cacheAge(for key: String) -> TimeInterval? {
        let expirationTimestamp = userDefaults.double(forKey: cacheExpirationPrefix + key)
        if expirationTimestamp == 0 {
            return nil
        }
        
        let currentTimestamp = Date().timeIntervalSince1970
        return currentTimestamp - expirationTimestamp
    }
}
