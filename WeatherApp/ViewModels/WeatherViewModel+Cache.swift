import Foundation
import Combine

// This extension adds caching support to the WeatherViewModel
extension WeatherViewModel {
    
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
    
    // Fetch fresh data when cache is missing or expired
    private func fetchFreshWeatherData(for coordinates: String, locationName: String) {
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                self.isRefreshing = false
                
                if case .failure(let error) = completion {
                    self.error = error.localizedDescription
                    
                    // Try to load stale cache as fallback on error
                    self.tryLoadStaleCacheOnError(for: locationName)
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                self.weatherData = weatherData
                self.alerts = alerts
                
                // Update location name if needed
                if self.weatherData.location.isEmpty {
                    self.weatherData.location = locationName
                }
                
                // Cache the data
                self.weatherCacheService.save(weatherData: weatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Fetch only hourly data if daily data is still valid
    private func fetchFreshHourlyData(for coordinates: String, locationName: String) {
        // This is a simplified approach - in a real app, you might want to have a separate API endpoint
        // that only returns hourly data to save bandwidth
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                if case .failure(let error) = completion {
                    print("Failed to refresh hourly data: \(error.localizedDescription)")
                    // Not updating error state since we already have valid daily data
                }
            }, receiveValue: { [weak self] (weatherData, _) in
                guard let self = self else { return }
                
                // Only update the hourly data, keep daily data from cache
                self.weatherData.hourly = weatherData.hourly
                
                // Update the cache with the new hourly data
                var updatedWeatherData = self.weatherData
                updatedWeatherData.hourly = weatherData.hourly
                self.weatherCacheService.save(weatherData: updatedWeatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Try to load stale cache as fallback when API request fails
    private func tryLoadStaleCacheOnError(for locationName: String) {
        // This method would try to load cached data even if expired
        // In a real app, this would need additional cache handling logic
        
        // For now, we'll simulate this by checking UserDefaults directly
        // A more robust implementation would have a dedicated method in WeatherCacheService
        let cacheKey = "weatherCache_\(locationName.replacingOccurrences(of: " ", with: "_").lowercased())"
        
        if let encodedData = UserDefaults.standard.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode(WeatherCache.self, from: encodedData) {
            self.weatherData = cache.weatherData
            self.error = "Using cached data from \(formatDate(cache.dailyExpiration)). Couldn't refresh."
        }
    }
    
    // Get location name from coordinates
    private func getLocationNameFromCoordinates(_ coordinates: String) -> String? {
        // Check if this is a saved location
        let components = coordinates.split(separator: ",")
        if components.count == 2,
           let lat = Double(components[0]),
           let lon = Double(components[1]) {
            
            let savedLocation = locationManager.savedLocations.first { location in
                abs(location.latitude - lat) < 0.01 && abs(location.longitude - lon) < 0.01
            }
            
            if let location = savedLocation {
                return location.name
            }
        }
        
        // Check if we have a cached name
        if let lastCoords = UserDefaults.standard.string(forKey: "lastCoordinates"),
           lastCoords == coordinates,
           let lastName = UserDefaults.standard.string(forKey: "lastLocationName") {
            return lastName
        }
        
        return nil
    }
    
    // Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Clear the cache for the current location
    func clearCache() {
        if let locationName = weatherData.location {
            weatherCacheService.clearCache(for: locationName)
        }
    }
    
    // Clear all cached data
    func clearAllCaches() {
        weatherCacheService.clearCache()
    }
}
