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
    
    // Fetch fresh data from the API
    private func fetchFreshWeatherData(for coordinates: String, locationName: String) {
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                self.isRefreshing = false
                
                if case .failure(let error) = completion {
                    self.error = error.localizedDescription
                    
                    // Try to use cached data even if expired as fallback
                    self.tryLoadExpiredCache(for: locationName)
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                
                // Update view model data
                self.weatherData = weatherData
                self.alerts = alerts
                
                // Save to cache
                self.weatherCacheService.save(weatherData: weatherData, for: locationName)
                
                // Save last coordinates
                UserDefaults.standard.set(coordinates, forKey: "lastCoordinates")
            })
            .store(in: &cancellables)
    }
    
    // Fetch only hourly data when daily data is still valid
    private func fetchFreshHourlyData(for coordinates: String, locationName: String) {
        // This would typically call a different endpoint that returns only hourly data
        // For this example, we'll just use the same endpoint but only update hourly data
        
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                if case .failure(let error) = completion {
                    print("Failed to fetch hourly data: \(error.localizedDescription)")
                    // Don't update error state since we already have daily data
                }
            }, receiveValue: { [weak self] (freshData, _) in
                guard let self = self else { return }
                
                // Only update hourly data, keeping our cached daily data
                self.weatherData.hourly = freshData.hourly
                
                // Update cache with new hourly data
                self.weatherCacheService.save(weatherData: self.weatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Try to load expired cache data as a fallback when network fails
    private func tryLoadExpiredCache(for location: String) {
        // This would need a separate method in the cache service that ignores expiration
        // For now, we'll just show a message to the user
        if self.weatherData.daily.isEmpty {
            self.error = "Network error and no cached data available. Please try again later."
        } else {
            self.error = "Network error. Showing cached data that may be outdated."
        }
    }
    
    // Extract location name from coordinates string
    private func getLocationNameFromCoordinates(_ coordinates: String) -> String? {
        // Check if we already have a name saved for these coordinates
        if let savedName = UserDefaults.standard.string(forKey: "name_\(coordinates)") {
            return savedName
        }
        
        // Check if this is one of our saved locations
        let components = coordinates.split(separator: ",")
        if components.count == 2,
           let lat = Double(components[0]),
           let lon = Double(components[1]) {
            for location in locationManager.savedLocations {
                // Check if coordinates are close (within 1km)
                let savedLat = location.latitude
                let savedLon = location.longitude
                
                // Very basic distance check
                if abs(lat - savedLat) < 0.01 && abs(lon - savedLon) < 0.01 {
                    return location.name
                }
            }
        }
        
        return nil
    }
    
    // Force refresh data even if we have a valid cache
    func forceRefreshWeather() {
        isRefreshing = true
        error = nil
        
        // Use last coordinates or get current location
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
            let locationName = UserDefaults.standard.string(forKey: "lastLocationName") ?? "Unknown Location"
            fetchFreshWeatherData(for: lastCoordinates, locationName: locationName)
        } else {
            requestCurrentLocation()
        }
    }
    
    // Update UI based on cache status
    func updateCacheIndicator() -> String {
        guard let lastUpdated = weatherData.metadata?.updated else {
            return "Unknown"
        }
        
        // Format last updated time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        
        return "Last updated: \(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(Int(lastUpdated) ?? 0))))"
    }
    
    // Clear all cached data
    func clearAllCaches() {
        weatherCacheService.clearCache()
    }
}
