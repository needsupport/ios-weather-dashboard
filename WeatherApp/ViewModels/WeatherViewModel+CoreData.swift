import Foundation
import Combine
import CoreLocation

/// Extension to add CoreData functionality to WeatherViewModel
extension WeatherViewModel {
    
    /// Initialize CoreData integration
    func initializeCoreData() {
        // Migrate data from UserDefaults to CoreData if needed
        DataMigrationService.shared.migrateDataIfNeeded()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Migration error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { successful in
                    if successful {
                        print("Migration completed successfully")
                        // After migration, load saved locations from CoreData
                        self.loadSavedLocationsFromCoreData()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Load saved locations from CoreData
    func loadSavedLocationsFromCoreData() {
        CoreDataManager.shared.fetchAllLocations()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error loading locations: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] locations in
                    guard let self = self else { return }
                    
                    // Update saved locations
                    self.savedLocations = locations.map { location in
                        return SavedLocation(
                            id: location.id,
                            name: location.name,
                            latitude: location.latitude,
                            longitude: location.longitude,
                            isFavorite: location.isFavorite
                        )
                    }
                    
                    // If we have a selected location, load it
                    if let selectedLocation = self.selectedLocation,
                       let selectedLocationName = self.selectedLocationName {
                        // Find matching location in saved locations
                        if let matchingLocation = self.savedLocations.first(where: { saved in
                            saved.latitude == selectedLocation.latitude &&
                            saved.longitude == selectedLocation.longitude
                        }) {
                            // Load weather data from CoreData for this location
                            self.loadWeatherDataFromCoreData(for: matchingLocation.id)
                        }
                    } else if let firstLocation = self.savedLocations.first {
                        // No selected location, use first saved location
                        self.selectedLocation = firstLocation
                        self.selectedLocationName = firstLocation.name
                        self.loadWeatherDataFromCoreData(for: firstLocation.id)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Load weather data from CoreData for a location
    /// - Parameter locationId: The ID of the location
    func loadWeatherDataFromCoreData(for locationId: String) {
        CoreDataManager.shared.fetchWeatherData(for: locationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error loading weather data: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] weatherData in
                    guard let self = self else { return }
                    
                    if let weatherData = weatherData {
                        // Update view model data
                        self.weatherData = weatherData
                        self.isLoading = false
                        self.error = nil
                        
                        // Check if data is stale
                        if self.isDataStale(weatherData) {
                            // If stale, refresh from API
                            self.refreshWeather()
                        }
                    } else {
                        // No cached data, refresh from API
                        self.refreshWeather()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Save current weather data to CoreData
    func saveWeatherDataToCoreData() {
        guard let location = selectedLocation,
              let locationName = selectedLocationName else {
            return
        }
        
        // First ensure location is saved
        CoreDataManager.shared.saveLocation(
            name: locationName,
            latitude: location.latitude,
            longitude: location.longitude
        )
        .flatMap { locationId -> AnyPublisher<Void, Error> in
            // Then save weather data for this location
            return CoreDataManager.shared.saveWeatherData(self.weatherData, for: locationId)
        }
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error saving weather data: \(error.localizedDescription)")
                }
            },
            receiveValue: { _ in
                print("Weather data saved successfully")
            }
        )
        .store(in: &cancellables)
    }
    
    /// Save a location to CoreData
    /// - Parameters:
    ///   - name: Location name
    ///   - coordinates: Location coordinates
    ///   - isFavorite: Whether this is a favorite location
    func saveLocationToCoreData(name: String, coordinates: CLLocationCoordinate2D, isFavorite: Bool = false) {
        CoreDataManager.shared.saveLocation(
            name: name,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            isFavorite: isFavorite
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error saving location: \(error.localizedDescription)")
                }
            },
            receiveValue: { [weak self] locationId in
                guard let self = self else { return }
                
                // Update saved locations
                self.loadSavedLocationsFromCoreData()
                
                // Update selected location if needed
                if self.selectedLocation == nil {
                    let newLocation = SavedLocation(
                        id: locationId,
                        name: name,
                        latitude: coordinates.latitude,
                        longitude: coordinates.longitude,
                        isFavorite: isFavorite
                    )
                    self.selectedLocation = newLocation
                    self.selectedLocationName = name
                    self.loadWeatherDataFromCoreData(for: locationId)
                }
            }
        )
        .store(in: &cancellables)
    }
    
    /// Delete a saved location
    /// - Parameter locationId: The ID of the location to delete
    func deleteLocationFromCoreData(with locationId: String) {
        CoreDataManager.shared.deleteLocation(with: locationId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error deleting location: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Update saved locations
                    self.loadSavedLocationsFromCoreData()
                    
                    // If deleted location was selected, select another one
                    if let selectedLocation = self.selectedLocation,
                       let deletedLocation = self.savedLocations.first(where: { $0.id == locationId }),
                       deletedLocation.latitude == selectedLocation.latitude &&
                       deletedLocation.longitude == selectedLocation.longitude {
                        
                        if let firstLocation = self.savedLocations.first(where: { $0.id != locationId }) {
                            self.selectedLocation = firstLocation
                            self.selectedLocationName = firstLocation.name
                            self.loadWeatherDataFromCoreData(for: firstLocation.id)
                        } else {
                            self.selectedLocation = nil
                            self.selectedLocationName = nil
                            self.weatherData = WeatherData()
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Toggle favorite status for a location
    /// - Parameter locationId: The ID of the location
    func toggleFavorite(for locationId: String) {
        // Find the location in saved locations
        guard let locationIndex = savedLocations.firstIndex(where: { $0.id == locationId }) else {
            return
        }
        
        let location = savedLocations[locationIndex]
        let newFavoriteStatus = !location.isFavorite
        
        // Update in CoreData
        CoreDataManager.shared.saveLocation(
            name: location.name,
            latitude: location.latitude,
            longitude: location.longitude,
            isFavorite: newFavoriteStatus
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error updating favorite status: \(error.localizedDescription)")
                }
            },
            receiveValue: { [weak self] _ in
                guard let self = self else { return }
                
                // Update local state
                self.savedLocations[locationIndex].isFavorite = newFavoriteStatus
                
                // Notify observers
                self.objectWillChange.send()
            }
        )
        .store(in: &cancellables)
    }
    
    /// Check if weather data is stale and needs refresh
    /// - Parameter weatherData: The weather data to check
    /// - Returns: True if data is stale
    private func isDataStale(_ weatherData: WeatherData) -> Bool {
        // Check if metadata contains update timestamp
        guard let metadata = weatherData.metadata,
              let updatedString = metadata.updated,
              let updatedDate = ISO8601DateFormatter().date(from: updatedString) else {
            return true
        }
        
        // Consider data stale if older than 1 hour
        let staleThreshold: TimeInterval = 60 * 60 // 1 hour in seconds
        let timeSinceUpdate = Date().timeIntervalSince(updatedDate)
        
        return timeSinceUpdate > staleThreshold
    }
}
