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
    
    // Extract location name from coordinates
    private func getLocationNameFromCoordinates(_ coordinates: String) -> String? {
        // Try to get name from saved locations
        let components = coordinates.split(separator: ",")
        if components.count == 2,
           let lat = Double(components[0]),
           let lon = Double(components[1]) {
            
            // Check if it matches any saved location
            for location in locationManager.savedLocations {
                if abs(location.latitude - lat) < 0.01 && abs(location.longitude - lon) < 0.01 {
                    return location.name
                }
            }
            
            // Otherwise, try to get from UserDefaults if it's the last location
            if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates"),
               lastCoordinates == coordinates,
               let lastName = UserDefaults.standard.string(forKey: "lastLocationName") {
                return lastName
            }
        }
        
        return nil
    }
    
    // Fetch fresh data from API and cache it
    private func fetchFreshWeatherData(for coordinates: String, locationName: String) {
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                self.isRefreshing = false
                
                if case .failure(let error) = completion {
                    self.error = error.localizedDescription
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                self.weatherData = weatherData
                self.alerts = alerts
                
                // Cache the data
                self.weatherCacheService.save(weatherData: weatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Fetch only hourly data when daily is still valid
    private func fetchFreshHourlyData(for coordinates: String, locationName: String) {
        // This would be a custom endpoint to fetch only hourly data
        // For simplicity, we'll use the full weather fetch here
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                if case .failure(let error) = completion {
                    print("Error updating hourly data: \(error.localizedDescription)")
                    // Non-critical error, don't update UI error state
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                
                // Only update the hourly data
                self.weatherData.hourly = weatherData.hourly
                
                // Update alerts if there are any new ones
                if !alerts.isEmpty {
                    self.alerts = alerts
                }
                
                // Cache the complete updated data
                self.weatherCacheService.save(weatherData: self.weatherData, for: locationName)
            })
            .store(in: &cancellables)
    }
    
    // Clear cache for specific location
    func clearCache(for location: String? = nil) {
        weatherCacheService.clearCache(for: location)
    }
    
    // Check if we have cached data for a location
    func hasCachedData(for location: String) -> Bool {
        return weatherCacheService.loadCachedData(for: location) != nil
    }
    
    // Refresh data for current location
    func refreshWeatherWithCache() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        // If we have a selected location, refresh that
        if let locationName = weatherData.location, !locationName.isEmpty {
            // Find the coordinates for this location
            if let location = locationManager.savedLocations.first(where: { $0.name == locationName }) {
                fetchWeatherDataWithCache(for: location.coordinateString)
                return
            }
        }
        
        // Otherwise use last known location
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
            fetchWeatherDataWithCache(for: lastCoordinates)
            return
        }
        
        // If all else fails, request current location
        requestCurrentLocation()
    }
    
    // Initialize with offline data if available
    func initializeWithCachedData() {
        // First try last location
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates"),
           let lastLocationName = UserDefaults.standard.string(forKey: "lastLocationName"),
           let cachedData = weatherCacheService.loadCachedData(for: lastLocationName) {
            
            self.weatherData = cachedData
            return
        }
        
        // Then try any saved location
        for location in locationManager.savedLocations {
            if let cachedData = weatherCacheService.loadCachedData(for: location.name) {
                self.weatherData = cachedData
                return
            }
        }
        
        // No cached data available, will need to fetch fresh data
    }
}
