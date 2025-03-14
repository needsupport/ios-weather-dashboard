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
                    
                    // Try to use cached data even if expired as a fallback
                    self.tryLoadExpiredCache(for: locationName)
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                
                // Update the view model data
                self.weatherData = weatherData
                self.alerts = alerts
                
                // If we have a location name from reverse geocoding, use it
                if !locationName.contains("Unknown") {
                    self.weatherData.location = locationName
                }
                
                // Cache the data for future use
                self.weatherCacheService.save(weatherData: weatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Fetch only hourly data if the daily data is still valid
    private func fetchFreshHourlyData(for coordinates: String, locationName: String) {
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                if case .failure(let error) = completion {
                    // Just log the error - we already have daily data
                    print("Error fetching hourly data: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] (weatherData, _) in
                guard let self = self else { return }
                
                // Only update hourly data, keeping our cached daily data
                self.weatherData.hourly = weatherData.hourly
                
                // Update the cache with the new combined data
                self.weatherCacheService.save(weatherData: self.weatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Try to load expired cache data as a fallback when network fails
    private func tryLoadExpiredCache(for locationName: String) {
        // This would need a separate method in the cache service to bypass expiration checks
        // For now, we'll just show the error
    }
    
    // Refresh data, potentially using cache for fast display while updating in background
    func refreshWeatherWithCache() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
            // First show cached data immediately if available
            let locationName = UserDefaults.standard.string(forKey: "lastLocationName") ?? "Unknown Location"
            if let cachedData = weatherCacheService.loadCachedData(for: locationName) {
                self.weatherData = cachedData
            }
            
            // Then fetch fresh data
            fetchFreshWeatherData(for: lastCoordinates, locationName: locationName)
        } else {
            // No last coordinates available, request location
            requestLocation()
            isRefreshing = false
        }
    }
    
    // Clear cache for current location
    func clearCache() {
        if let locationName = weatherData.location, !locationName.isEmpty {
            weatherCacheService.clearCache(for: locationName)
        }
    }
    
    // Get location name from coordinates string
    private func getLocationNameFromCoordinates(_ coordinates: String) -> String? {
        // Check if we have a stored name for these coordinates
        let savedLocations = locationManager.savedLocations
        let coordinateParts = coordinates.split(separator: ",")
        
        if coordinateParts.count == 2,
           let lat = Double(coordinateParts[0]),
           let lon = Double(coordinateParts[1]) {
            
            // Check saved locations
            for location in savedLocations {
                // Use approximate matching with small delta
                let latDelta = abs(location.latitude - lat)
                let lonDelta = abs(location.longitude - lon)
                
                if latDelta < 0.01 && lonDelta < 0.01 {
                    return location.name
                }
            }
            
            // Check for last known location
            if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates"),
               let lastLocationName = UserDefaults.standard.string(forKey: "lastLocationName"),
               lastCoordinates == coordinates {
                return lastLocationName
            }
        }
        
        return nil
    }
}
