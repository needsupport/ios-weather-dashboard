import Foundation
import Combine
import CoreLocation

extension WeatherViewModel {
    
    /// Refresh weather data for all saved locations in the background
    /// - Returns: Async task that completes when all refreshes are done
    @available(iOS 15.0, *)
    func refreshAllLocationsInBackground() async throws {
        let locations = await withCheckedContinuation { continuation in
            CoreDataManager.shared.fetchAllLocations()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("Error fetching locations for background refresh: \(error.localizedDescription)")
                            continuation.resume(returning: [])
                        }
                    },
                    receiveValue: { locations in
                        continuation.resume(returning: locations)
                    }
                )
                .store(in: &cancellables)
        }
        
        // Create a group of tasks to refresh all locations
        await withThrowingTaskGroup(of: Void.self) { group in
            for location in locations {
                group.addTask {
                    try await self.refreshLocationInBackground(
                        coordinates: CLLocationCoordinate2D(
                            latitude: location.latitude,
                            longitude: location.longitude
                        ),
                        locationId: location.id
                    )
                }
            }
            
            // Wait for all tasks to complete
            try await group.waitForAll()
        }
    }
    
    /// Refresh a specific location in the background
    /// - Parameters:
    ///   - coordinates: Location coordinates
    ///   - locationId: Location ID in CoreData
    /// - Returns: Async task that completes when refresh is done
    @available(iOS 15.0, *)
    private func refreshLocationInBackground(coordinates: CLLocationCoordinate2D, locationId: String) async throws {
        // Fetch fresh weather data
        let response = try await withCheckedThrowingContinuation { continuation in
            weatherService.fetchWeatherData(for: coordinates, unit: preferences.unit)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { response in
                        continuation.resume(returning: response)
                    }
                )
                .store(in: &cancellables)
        }
        
        // Save to CoreData
        try await withCheckedThrowingContinuation { continuation in
            CoreDataManager.shared.saveWeatherData(response.weatherData, for: locationId)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
    }
}
