import Foundation
import CoreLocation
import Combine

/// Service for migrating data from UserDefaults to CoreData
class DataMigrationService {
    static let shared = DataMigrationService()
    
    private let coreDataManager = CoreDataManager.shared
    private let cacheManager = WeatherCacheManager.shared
    private let userDefaults = UserDefaults.standard
    
    private let migrationCompletedKey = "coreDataMigrationCompleted"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Migrates data if not already done
    /// - Returns: Publisher that emits when migration completes or if already done
    func migrateDataIfNeeded() -> AnyPublisher<Bool, Error> {
        // Check if migration has already been performed
        if userDefaults.bool(forKey: migrationCompletedKey) {
            return Just(true)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return migrateWeatherData()
            .flatMap { _ in self.migrateLocations() }
            .map { _ in
                // Mark migration as completed
                self.userDefaults.set(true, forKey: self.migrationCompletedKey)
                return true
            }
            .eraseToAnyPublisher()
    }
    
    /// Migrates weather data from UserDefaults to CoreData
    /// - Returns: Publisher that emits when migration completes
    private func migrateWeatherData() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // Get all saved locations from UserDefaults
            guard let savedLocationsData = self.userDefaults.data(forKey: "savedLocations"),
                  let savedLocations = try? JSONDecoder().decode([String: [Double]].self, from: savedLocationsData) else {
                // No saved locations, migration complete
                promise(.success(true))
                return
            }
            
            // Create a publisher for each location to migrate
            let publishers = savedLocations.map { (name, coordinates) -> AnyPublisher<Bool, Error> in
                let latitude = coordinates[0]
                let longitude = coordinates[1]
                let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                
                return self.migrateWeatherDataForLocation(location, name: name)
            }
            
            // Combine all publishers and complete when all are done
            Publishers.MergeMany(publishers)
                .collect()
                .map { _ in true }
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { _ in
                        promise(.success(true))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    /// Migrates weather data for a specific location
    /// - Parameters:
    ///   - location: The location coordinates
    ///   - name: The location name
    /// - Returns: Publisher that emits when migration completes
    private func migrateWeatherDataForLocation(_ location: CLLocationCoordinate2D, name: String) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // Get cached weather data from UserDefaults
            if let cachedData = self.cacheManager.getCachedWeatherData(for: location) {
                // Save to CoreData
                let publisher = self.coreDataManager.saveLocation(
                    name: name,
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                .flatMap { locationId -> AnyPublisher<Void, Error> in
                    // Save the weather data associated with this location
                    return self.coreDataManager.saveWeatherData(cachedData.weatherData, for: locationId)
                }
                
                publisher.sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { _ in
                        promise(.success(true))
                    }
                )
                .store(in: &self.cancellables)
            } else {
                // No cached data for this location
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Migrates saved locations from UserDefaults to CoreData
    /// - Returns: Publisher that emits when migration completes
    private func migrateLocations() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // Get all saved locations from UserDefaults
            guard let savedLocationsData = self.userDefaults.data(forKey: "savedLocations"),
                  let savedLocations = try? JSONDecoder().decode([String: [Double]].self, from: savedLocationsData) else {
                // No saved locations, migration complete
                promise(.success(true))
                return
            }
            
            // Create a publisher for each location to migrate
            let publishers = savedLocations.map { (name, coordinates) -> AnyPublisher<String, Error> in
                let latitude = coordinates[0]
                let longitude = coordinates[1]
                
                // Get favorite status (if exists)
                let favoriteLocationsKey = "favoriteLocations"
                var isFavorite = false
                
                if let favoritesData = self.userDefaults.data(forKey: favoriteLocationsKey),
                   let favorites = try? JSONDecoder().decode([String].self, from: favoritesData) {
                    isFavorite = favorites.contains(name)
                }
                
                // Save the location to CoreData
                return self.coreDataManager.saveLocation(
                    name: name,
                    latitude: latitude,
                    longitude: longitude,
                    isFavorite: isFavorite
                )
            }
            
            // Combine all publishers and complete when all are done
            Publishers.MergeMany(publishers)
                .collect()
                .map { _ in true }
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { _ in
                        promise(.success(true))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    /// Resets migration status (for testing)
    func resetMigrationStatus() {
        userDefaults.set(false, forKey: migrationCompletedKey)
    }
}
