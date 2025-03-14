import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    // Published properties that update the UI
    @Published var currentLocation: CLLocation?
    @Published var locationStatus: CLAuthorizationStatus
    @Published var lastKnownAddress: String?
    @Published var isLoadingLocation: Bool = false
    @Published var locationError: String?
    
    // Publishers for location updates and errors
    let locationUpdatePublisher = PassthroughSubject<CLLocationCoordinate2D, Never>()
    let locationErrorPublisher = PassthroughSubject<Error, Never>()
    
    // The CoreLocation manager
    private let locationManager = CLLocationManager()
    
    // Geocoder for reverse geocoding
    private let geocoder = CLGeocoder()
    
    // Saved locations
    @Published var savedLocations: [SavedLocation] = []
    
    override init() {
        self.locationStatus = .notDetermined
        super.init()
        
        // Setup location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Lower accuracy for weather app
        locationManager.distanceFilter = 5000 // Only update when moved 5km
        
        // Load saved locations
        loadSavedLocations()
    }
    
    // Request location permission
    func requestLocationPermission() {
        isLoadingLocation = true
        locationManager.requestWhenInUseAuthorization()
    }
    
    // Start getting the current location
    func startLocationUpdates() {
        isLoadingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }
    
    // Get a single location update
    func requestLocation() {
        isLoadingLocation = true
        locationError = nil
        locationManager.requestLocation()
    }
    
    // Stop location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLoadingLocation = false
    }
    
    // Convert location to address
    func reverseGeocode(location: CLLocation, completion: @escaping (String?) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            var address = ""
            
            // Get locality (city)
            if let locality = placemark.locality {
                address = locality
            }
            
            // Add administrative area (state/province)
            if let administrativeArea = placemark.administrativeArea {
                if !address.isEmpty {
                    address += ", "
                }
                address += administrativeArea
            }
            
            // If we couldn't get city or state, use the name
            if address.isEmpty, let name = placemark.name {
                address = name
            }
            
            self.lastKnownAddress = address
            completion(address)
        }
    }
    
    // Forward geocode - convert address to coordinates
    func geocode(address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Forward geocoding error: \(error.localizedDescription)")
                self.locationError = "Couldn't find location: \(error.localizedDescription)"
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                self.locationError = "No location found for this address"
                completion(nil)
                return
            }
            
            completion(location.coordinate)
        }
    }
    
    // MARK: - Saved Locations
    
    // Add a new saved location
    func addSavedLocation(name: String, coordinates: CLLocationCoordinate2D) {
        let newLocation = SavedLocation(
            id: UUID().uuidString,
            name: name,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
        
        savedLocations.append(newLocation)
        saveSavedLocations()
    }
    
    // Remove a saved location
    func removeSavedLocation(id: String) {
        savedLocations.removeAll(where: { $0.id == id })
        saveSavedLocations()
    }
    
    // Save locations to UserDefaults
    private func saveSavedLocations() {
        if let encoded = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(encoded, forKey: "savedLocations")
        }
    }
    
    // Load locations from UserDefaults
    private func loadSavedLocations() {
        if let savedData = UserDefaults.standard.data(forKey: "savedLocations"),
           let decodedLocations = try? JSONDecoder().decode([SavedLocation].self, from: savedData) {
            savedLocations = decodedLocations
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    // Authorization status changed
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        
        switch locationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Start getting location if authorized
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            // Handle denied access
            stopLocationUpdates()
            locationError = "Location access denied. Please enable it in Settings."
            locationErrorPublisher.send(NSError(
                domain: "LocationDeniedError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access denied"]
            ))
        case .notDetermined:
            // Wait for user decision
            break
        @unknown default:
            // Future-proof
            break
        }
    }
    
    // Location updates received
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update current location
        currentLocation = location
        isLoadingLocation = false
        locationError = nil
        
        // Notify subscribers
        locationUpdatePublisher.send(location.coordinate)
        
        // Reverse geocode to get address
        reverseGeocode(location: location) { _ in
            // Address is stored in lastKnownAddress property
        }
        
        // If we only requested a single location, stop updates
        if manager.desiredAccuracy == kCLLocationAccuracyThreeKilometers {
            stopLocationUpdates()
        }
    }
    
    // Location manager error
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle error
        isLoadingLocation = false
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "Location access denied"
            case .locationUnknown:
                locationError = "Unable to determine location"
            default:
                locationError = "Location error: \(error.localizedDescription)"
            }
        } else {
            locationError = "Error getting location: \(error.localizedDescription)"
        }
        
        // Notify subscribers
        locationErrorPublisher.send(error)
    }
}

// MARK: - Saved Location Model
struct SavedLocation: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var coordinateString: String {
        "\(latitude),\(longitude)"
    }
    
    static func == (lhs: SavedLocation, rhs: SavedLocation) -> Bool {
        lhs.id == rhs.id
    }
}
