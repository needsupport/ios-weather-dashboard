import Foundation
import Combine
import CoreLocation

/// Central location manager that provides reactive location updates
class LocationManager: NSObject, ObservableObject {
    // MARK: - Singleton Instance
    static let shared = LocationManager()
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastKnownLocation: CLLocation?
    @Published var lastError: Error?
    @Published var savedLocations: [SavedLocation] = []
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let locationSubject = PassthroughSubject<CLLocation, Error>()
    private let userDefaults = UserDefaults.standard
    private let savedLocationsKey = "savedLocations"
    
    // MARK: - Initialization
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Lower accuracy is fine for weather
        locationManager.distanceFilter = 5000 // 5km minimum movement threshold
        
        // Load saved locations
        loadSavedLocations()
        
        // Restore last known location if available
        if let savedLat = userDefaults.double(forKey: "lastLocationLat"),
           let savedLong = userDefaults.double(forKey: "lastLocationLong"),
           savedLat != 0, savedLong != 0 {
            lastKnownLocation = CLLocation(latitude: savedLat, longitude: savedLong)
        }
    }
    
    // MARK: - Public Methods
    
    /// Request location permissions from the user
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Start updating location
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    /// Stop updating location
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Request a one-time location update
    func requestLocationOnce(completion: @escaping (CLLocation?) -> Void) {
        // If we already have a current location, use it immediately
        if let currentLocation = currentLocation {
            completion(currentLocation)
            return
        }
        
        // Check authorization status
        switch locationStatus {
        case .notDetermined:
            // Will request after user grants permission
            locationManager.requestWhenInUseAuthorization()
            
            // Set up a subscriber to get the location when available
            var cancellable: AnyCancellable?
            cancellable = locationPublisher()
                .timeout(.seconds(10), scheduler: RunLoop.main) // Timeout after 10 seconds
                .sink(
                    receiveCompletion: { [weak self] result in
                        if case .failure(let error) = result {
                            self?.lastError = error
                            completion(nil)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { location in
                        completion(location)
                        cancellable?.cancel()
                    }
                )
            
        case .restricted, .denied:
            // Permission denied, use last known location if available
            completion(lastKnownLocation)
            
        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized, request a fresh location
            var cancellable: AnyCancellable?
            cancellable = locationPublisher()
                .timeout(.seconds(10), scheduler: RunLoop.main)
                .sink(
                    receiveCompletion: { [weak self] result in
                        if case .failure(let error) = result {
                            self?.lastError = error
                            completion(self?.lastKnownLocation)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { location in
                        completion(location)
                        cancellable?.cancel()
                    }
                )
            
            locationManager.requestLocation()
            
        @unknown default:
            completion(lastKnownLocation)
        }
    }
    
    /// Returns a publisher that emits location updates
    func locationPublisher() -> AnyPublisher<CLLocation, Error> {
        return locationSubject.eraseToAnyPublisher()
    }
    
    /// Get a coordinates string from a location
    func coordinatesString(from location: CLLocation) -> String {
        return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    }
    
    /// Get string coordinates for the current location
    func currentLocationCoordinates() -> String? {
        if let location = currentLocation {
            return coordinatesString(from: location)
        } else if let location = lastKnownLocation {
            return coordinatesString(from: location)
        }
        return nil
    }
    
    // MARK: - Saved Locations
    
    /// Save a location
    func saveLocation(_ location: SavedLocation) {
        // Check if this location already exists
        if !savedLocations.contains(where: { $0.id == location.id }) {
            savedLocations.append(location)
            saveSavedLocations()
        }
    }
    
    /// Remove a saved location
    func removeLocation(withId id: String) {
        savedLocations.removeAll { $0.id == id }
        saveSavedLocations()
    }
    
    /// Save location to UserDefaults
    private func saveSavedLocations() {
        if let encodedData = try? JSONEncoder().encode(savedLocations) {
            userDefaults.set(encodedData, forKey: savedLocationsKey)
            userDefaults.synchronize()
        }
    }
    
    /// Load saved locations from UserDefaults
    private func loadSavedLocations() {
        if let savedData = userDefaults.data(forKey: savedLocationsKey),
           let decodedLocations = try? JSONDecoder().decode([SavedLocation].self, from: savedData) {
            savedLocations = decodedLocations
        }
    }
    
    /// Geocode a location to get a human-readable name
    func geocodeLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let placemark = placemarks?.first {
                var locationName = ""
                
                if let locality = placemark.locality {
                    locationName = locality
                }
                
                if let adminArea = placemark.administrativeArea, !adminArea.isEmpty {
                    if !locationName.isEmpty {
                        locationName += ", "
                    }
                    locationName += adminArea
                }
                
                if locationName.isEmpty && placemark.name != nil {
                    locationName = placemark.name!
                }
                
                completion(locationName.isEmpty ? "Unknown Location" : locationName)
            } else {
                completion(nil)
            }
        }
    }
    
    /// Check if a location is in the US
    func isUSLocation(_ location: CLLocation, completion: @escaping (Bool) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let placemark = placemarks?.first,
               let countryCode = placemark.isoCountryCode {
                completion(countryCode == "US")
            } else {
                completion(false)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update current location
        currentLocation = location
        lastKnownLocation = location
        
        // Save to UserDefaults
        userDefaults.set(location.coordinate.latitude, forKey: "lastLocationLat")
        userDefaults.set(location.coordinate.longitude, forKey: "lastLocationLong")
        
        // Emit to publisher
        locationSubject.send(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
        locationSubject.send(completion: .failure(error))
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            lastError = NSError(domain: "LocationManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Location access denied"
            ])
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Saved Location Model
struct SavedLocation: Codable, Identifiable {
    var id: String // Use UUID().uuidString for new locations
    var name: String
    var latitude: Double
    var longitude: Double
    var isFavorite: Bool
    
    func location() -> CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func coordinatesString() -> String {
        return "\(latitude),\(longitude)"
    }
}
