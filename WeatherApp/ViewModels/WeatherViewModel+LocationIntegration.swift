import Foundation
import Combine
import CoreLocation

// This extension adds enhanced location management to the WeatherViewModel
extension WeatherViewModel {
    
    // Setup location services
    func setupLocationServices() {
        // Subscribe to location updates
        locationManager.locationUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coordinate in
                guard let self = self else { return }
                
                // Cache this location as the last used
                self.saveLastUsedLocation(
                    name: self.locationManager.lastKnownAddress ?? "Current Location",
                    coordinates: coordinate
                )
                
                // Fetch weather for this location
                self.fetchWeatherData(for: "\(coordinate.latitude),\(coordinate.longitude)")
            }
            .store(in: &cancellables)
        
        // Subscribe to location errors
        locationManager.locationErrorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self = self else { return }
                
                // Update error state
                self.error = error.localizedDescription
                
                // Try to use last known location
                self.tryUseLastKnownLocation()
            }
            .store(in: &cancellables)
    }
    
    // Request current location
    func requestCurrentLocation() {
        isLoading = true
        error = nil
        
        // First check permission status
        switch locationManager.locationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestLocationPermission()
        case .denied, .restricted:
            error = "Location access denied. Please enable it in Settings."
            tryUseLastKnownLocation()
        @unknown default:
            error = "Unknown location authorization status."
            tryUseLastKnownLocation()
        }
    }
    
    // Try to use a saved location when current location isn't available
    private func tryUseLastKnownLocation() {
        isLoading = true
        
        // Check if we have a last used location
        if let lastLocation = UserDefaults.standard.string(forKey: "lastCoordinates") {
            fetchWeatherData(for: lastLocation)
            return
        }
        
        // Check if we have any saved locations
        if let firstSavedLocation = locationManager.savedLocations.first {
            fetchWeatherData(for: firstSavedLocation.coordinateString)
            return
        }
        
        // Fall back to a default location
        fetchWeatherData(for: "37.7749,-122.4194") // San Francisco
        isLoading = false
    }
    
    // Save current location
    func saveCurrentLocation(name: String? = nil) {
        guard let currentLocation = locationManager.currentLocation?.coordinate else {
            error = "No current location available to save"
            return
        }
        
        let locationName = name ?? locationManager.lastKnownAddress ?? "Saved Location"
        locationManager.addSavedLocation(name: locationName, coordinates: currentLocation)
    }
    
    // Use a saved location
    func useSavedLocation(_ location: SavedLocation) {
        weatherData.location = location.name
        fetchWeatherData(for: location.coordinateString)
    }
    
    // Search for a location by name
    func searchLocation(query: String) {
        isLoading = true
        error = nil
        
        locationManager.geocode(address: query) { [weak self] coordinates in
            guard let self = self, let coordinates = coordinates else {
                self?.isLoading = false
                self?.error = "Location not found. Please try another search."
                return
            }
            
            self.fetchWeatherData(for: "\(coordinates.latitude),\(coordinates.longitude)")
        }
    }
    
    // Save the last used location for future app launches
    private func saveLastUsedLocation(name: String, coordinates: CLLocationCoordinate2D) {
        let coordinateString = "\(coordinates.latitude),\(coordinates.longitude)"
        UserDefaults.standard.set(coordinateString, forKey: "lastCoordinates")
        UserDefaults.standard.set(name, forKey: "lastLocationName")
    }
    
    // Load weather data for a saved location
    func loadLocationWeather(location: SavedLocation) {
        // Check if we have cached data first
        if let cachedData = weatherCacheService.loadCachedData(for: location.name) {
            weatherData = cachedData
            weatherData.location = location.name
            isLoading = false
            return
        }
        
        // Fetch fresh data if no cache
        fetchWeatherData(for: location.coordinateString)
    }
    
    // Add a custom location
    func addCustomLocation(name: String, lat: Double, lon: Double) {
        let coordinates = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        locationManager.addSavedLocation(name: name, coordinates: coordinates)
    }
    
    // Remove a location from saved locations
    func removeSavedLocation(id: String) {
        locationManager.removeSavedLocation(id: id)
    }
}
