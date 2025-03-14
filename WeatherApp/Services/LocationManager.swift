import Foundation
import CoreLocation
import Combine

/// Saved location data structure
struct SavedLocation: Identifiable, Codable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    
    var coordinateString: String {
        return "\(latitude),\(longitude)"
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Unified location manager class that provides location services for the app
class LocationManager: NSObject, ObservableObject {
    // Singleton instance
    static let shared = LocationManager()
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var lastKnownAddress: String?
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var savedLocations: [SavedLocation] = []
    
    // MARK: - Publishers
    let locationUpdatePublisher = PassthroughSubject<CLLocationCoordinate2D, Never>()
    let locationErrorPublisher = PassthroughSubject<Error, Never>()
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationCallback: ((CLLocation?) -> Void)?
    private let userDefaults = UserDefaults.standard
    private let savedLocationsKey = "savedLocations"
    
    // MARK: - Initialization
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        // Load saved locations from UserDefaults
        loadSavedLocations()
        
        // Set initial authorization status
        locationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    /// Request location permission
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Request current location update
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    /// Request location once with completion handler
    func requestLocationOnce(completion: @escaping (CLLocation?) -> Void) {
        locationCallback = completion
        
        switch locationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            completion(nil) // Permission denied
        @unknown default:
            completion(nil)
        }
    }
    
    /// Geocode an address to coordinates
    func geocode(address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        geocoder.geocodeAddressString(address) { (placemarks, error) in
            guard error == nil, let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            guard let location = placemark.location else {
                completion(nil)
                return
            }
            
            completion(location.coordinate)
        }
    }
    
    /// Reverse geocode coordinates to address
    func reverseGeocode(coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            guard error == nil, let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            // Format address from placemark
            var addressString = ""
            if let locality = placemark.locality {
                addressString += locality
            }
            
            if let administrativeArea = placemark.administrativeArea {
                if !addressString.isEmpty {
                    addressString += ", "
                }
                addressString += administrativeArea
            }
            
            if addressString.isEmpty {
                if let name = placemark.name {
                    addressString = name
                } else {
                    addressString = "Unknown Location"
                }
            }
            
            completion(addressString)
        }
    }
    
    /// Add a location to saved locations
    func addSavedLocation(name: String, coordinates: CLLocationCoordinate2D) {
        let id = UUID().uuidString
        let newLocation = SavedLocation(
            id: id,
            name: name,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
        
        savedLocations.append(newLocation)
        saveSavedLocations()
    }
    
    /// Remove a location from saved locations
    func removeSavedLocation(id: String) {
        savedLocations.removeAll { $0.id == id }
        saveSavedLocations()
    }
    
    // MARK: - Private Methods
    
    /// Save locations to UserDefaults
    private func saveSavedLocations() {
        if let encodedData = try? JSONEncoder().encode(savedLocations) {
            userDefaults.set(encodedData, forKey: savedLocationsKey)
        }
    }
    
    /// Load locations from UserDefaults
    private func loadSavedLocations() {
        if let savedData = userDefaults.data(forKey: savedLocationsKey),
           let locations = try? JSONDecoder().decode([SavedLocation].self, from: savedData) {
            savedLocations = locations
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        // Update current location
        currentLocation = location
        
        // Send update through the publisher
        locationUpdatePublisher.send(location.coordinate)
        
        // Handle callback if set
        if let callback = locationCallback {
            callback(location)
            locationCallback = nil
        }
        
        // Update address
        reverseGeocode(coordinate: location.coordinate) { [weak self] address in
            self?.lastKnownAddress = address
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        
        // Send error through the publisher
        locationErrorPublisher.send(error)
        
        // Handle callback if set
        if let callback = locationCallback {
            callback(nil)
            locationCallback = nil
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            if let callback = locationCallback {
                callback(nil)
                locationCallback = nil
            }
        case .notDetermined:
            // Wait for user to grant permission
            break
        @unknown default:
            break
        }
    }
}
