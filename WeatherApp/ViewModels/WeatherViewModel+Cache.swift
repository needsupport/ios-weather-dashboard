import Foundation
import Combine

// This extension adds caching support to the WeatherViewModel
extension WeatherViewModel {
    
    // Private cache service property
    lazy var weatherCacheService: WeatherCacheService = {
        return WeatherCacheService()
    }()
    
    // Check cache before making an API call
    func fetchWeatherDataWithCache(for coordinates: String) {
        isLoading = true
        error = nil
        
        // Get location name from coordinates if possible
        let locationName = getLocationNameFromCoordinates(coordinates) ?? "Unknown Location"
        
        // Try to get data from cache first
        if let cachedData = weatherCacheService.loadCachedData(for: locationName) {
            // We have valid cached data
            self.weatherData = cachedData
            self.isLoading = false
            self.isRefreshing = false
            
            // If we only have daily data (hourly expired), fetch fresh hourly data
            if cachedData.hourly.isEmpty {
                fetchFreshHourlyData(for: coordinates, locationName: locationName)
            }
            
            return
        }
        
        // No cache or expired cache, fetch fresh data
        fetchFreshWeatherData(for: coordinates, locationName: locationName)
    }
    
    // Fetch fresh data from API
    private func fetchFreshWeatherData(for coordinates: String, locationName: String) {
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                self.isRefreshing = false
                
                if case .failure(let error) = completion {
                    self.handleDataFetchError(error, for: locationName)
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                
                // Update with new data
                self.weatherData = weatherData
                self.alerts = alerts
                
                // Cache the data
                self.weatherCacheService.save(weatherData: weatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Fetch only hourly data (when daily data is still valid but hourly expired)
    private func fetchFreshHourlyData(for coordinates: String, locationName: String) {
        // This would typically require a specialized API endpoint
        // For now, we'll just fetch all data but only update the hourly portion
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                if case .failure(let error) = completion {
                    // Non-critical error - we already have daily data
                    print("Error refreshing hourly data: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] (weatherData, _) in
                guard let self = self else { return }
                
                // Only update hourly data
                self.weatherData.hourly = weatherData.hourly
                
                // Update the cache
                self.weatherCacheService.save(weatherData: self.weatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Handle errors during data fetch with fallback to cache
    private func handleDataFetchError(_ error: Error, for locationName: String) {
        // Set error message for UI
        self.error = error.localizedDescription
        
        // Try to get any cached data, even if expired
        if let expiredCache = getExpiredCache(for: locationName) {
            self.weatherData = expiredCache
            // Show both cached data and error message
            self.error = "Using cached data from \(formatCacheDate(expiredCache.metadata?.updated)). Error: \(error.localizedDescription)"
        }
    }
    
    // Get expired cache as a last resort
    private func getExpiredCache(for locationName: String) -> WeatherData? {
        let cacheKey = "weatherCache_\(locationName.replacingOccurrences(of: " ", with: "_").lowercased())"
        
        guard let encodedData = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }
        
        // Try to decode the cache regardless of expiration
        do {
            let cache = try JSONDecoder().decode(WeatherCache.self, from: encodedData)
            // Update the metadata to show it's using expired data
            var weatherData = cache.weatherData
            var metadataInfo = "Expired cache from "
            if let updated = weatherData.metadata?.updated {
                metadataInfo += updated
            } else {
                metadataInfo += "unknown time"
            }
            
            // Set or update metadata
            if weatherData.metadata == nil {
                weatherData.metadata = WeatherMetadata(
                    office: "Unknown",
                    gridX: "0",
                    gridY: "0",
                    timezone: TimeZone.current.identifier,
                    updated: metadataInfo
                )
            } else {
                weatherData.metadata?.updated = metadataInfo
            }
            
            return weatherData
        } catch {
            print("Error decoding expired cache: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Format cache date for display
    private func formatCacheDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "unknown time" }
        return dateString
    }
    
    // Try to get location name from coordinates
    private func getLocationNameFromCoordinates(_ coordinates: String) -> String? {
        // Check if this location is in saved locations
        let components = coordinates.split(separator: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        
        // Find matching saved location
        for location in locationManager.savedLocations {
            if abs(location.latitude - lat) < 0.01 && abs(location.longitude - lon) < 0.01 {
                return location.name
            }
        }
        
        // Check if we have a last known location name
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates"),
           lastCoordinates == coordinates,
           let lastLocationName = UserDefaults.standard.string(forKey: "lastLocationName") {
            return lastLocationName
        }
        
        return nil
    }
    
    // Clear cache for current location
    func clearCurrentLocationCache() {
        guard let locationName = weatherData.location, !locationName.isEmpty else {
            // Clear all cache if no specific location
            weatherCacheService.clearCache()
            return
        }
        
        weatherCacheService.clearCache(for: locationName)
    }
    
    // Refresh data with force reload (bypass cache)
    func forceRefreshWeather() {
        isRefreshing = true
        error = nil
        
        // Get current location coordinates
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
            // Skip cache and fetch fresh data
            fetchFreshWeatherData(
                for: lastCoordinates,
                locationName: weatherData.location
            )
        } else {
            // No coordinates, request location
            requestCurrentLocation()
        }
    }
    
    // Request current location from location manager
    private func requestCurrentLocation() {
        // Reset any previous errors
        error = nil
        isLoading = true
        
        // Request location update from the location manager
        locationManager.requestLocation()
    }
}
