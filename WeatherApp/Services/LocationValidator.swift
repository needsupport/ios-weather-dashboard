import Foundation
import CoreLocation
import Combine

/// A validator service to determine if a location is supported by the National Weather Service API
/// and provide appropriate fallback mechanisms for international locations
class LocationValidator {
    
    // Singleton instance
    static let shared = LocationValidator()
    
    // US Bounding Box - rough coordinates that encompass the US including Alaska and Hawaii
    private let usBoundingBox = (
        minLat: 18.0, // Southern tip of Hawaii
        maxLat: 72.0, // Northern Alaska
        minLon: -180.0, // Western Alaska (crossing the antimeridian)
        maxLon: -66.0  // Eastern Maine
    )
    
    // US Territories to include (rough center coordinates)
    private let usTerritories: [(name: String, lat: Double, lon: Double)] = [
        ("Puerto Rico", 18.2208, -66.5901),
        ("US Virgin Islands", 18.3358, -64.8963),
        ("Guam", 13.4443, 144.7937),
        ("American Samoa", -14.2710, -170.1322),
        ("Northern Mariana Islands", 15.0979, 145.6739)
    ]
    
    // Distance threshold for determining if a location is within a US territory (in kilometers)
    private let territoryThreshold: Double = 100.0
    
    private init() {}
    
    /// Check if a location is within the United States or its territories
    /// - Parameter coordinates: The coordinates to check
    /// - Returns: True if the location is within the US or its territories
    func isUSLocation(_ coordinates: CLLocationCoordinate2D) -> Bool {
        // Check if within main US bounding box
        let inMainUS = coordinates.latitude >= usBoundingBox.minLat &&
                       coordinates.latitude <= usBoundingBox.maxLat &&
                       coordinates.longitude >= usBoundingBox.minLon &&
                       coordinates.longitude <= usBoundingBox.maxLon
        
        if inMainUS {
            return true
        }
        
        // If not in the main bounding box, check proximity to US territories
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        
        for territory in usTerritories {
            let territoryLocation = CLLocation(latitude: territory.lat, longitude: territory.lon)
            let distance = location.distance(from: territoryLocation) / 1000.0 // Convert to km
            
            if distance <= territoryThreshold {
                return true
            }
        }
        
        return false
    }
    
    /// Find the nearest US location to the provided international coordinates
    /// Used as a fallback mechanism for non-US locations
    /// - Parameter coordinates: The international coordinates
    /// - Returns: A publisher that emits the nearest US location
    func findNearestUSLocation(to coordinates: CLLocationCoordinate2D) -> AnyPublisher<CLLocationCoordinate2D, Error> {
        return Future<CLLocationCoordinate2D, Error> { promise in
            // Simplified approach - find closest US territory or border location
            var closestLocation: CLLocation?
            var minDistance = Double.greatestFiniteMagnitude
            
            let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            
            // Check distance to all territories
            for territory in self.usTerritories {
                let territoryLocation = CLLocation(latitude: territory.lat, longitude: territory.lon)
                let distance = location.distance(from: territoryLocation)
                
                if distance < minDistance {
                    minDistance = distance
                    closestLocation = territoryLocation
                }
            }
            
            // Check distance to US mainland boundary points (simplified)
            let usBoundaryPoints: [(lat: Double, lon: Double)] = [
                // West Coast
                (32.5343, -117.1251), // San Diego
                (37.7749, -122.4194), // San Francisco
                (47.6062, -122.3321), // Seattle
                // East Coast
                (25.7617, -80.1918), // Miami
                (40.7128, -74.0060), // New York
                (42.3601, -71.0589), // Boston
                // North
                (48.5000, -97.0000), // Northern border with Canada (North Dakota)
                // South
                (26.0000, -97.5000), // Southern border with Mexico (Texas)
                // Alaska
                (64.2008, -149.4937), // Fairbanks
                // Hawaii
                (21.3069, -157.8583) // Honolulu
            ]
            
            for point in usBoundaryPoints {
                let boundaryLocation = CLLocation(latitude: point.lat, longitude: point.lon)
                let distance = location.distance(from: boundaryLocation)
                
                if distance < minDistance {
                    minDistance = distance
                    closestLocation = boundaryLocation
                }
            }
            
            if let closestUSLocation = closestLocation {
                promise(.success(CLLocationCoordinate2D(
                    latitude: closestUSLocation.coordinate.latitude,
                    longitude: closestUSLocation.coordinate.longitude
                )))
            } else {
                // Default to a central US location if no calculations worked
                promise(.success(CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Suggest a better API for the given location based on its coordinates
    /// - Parameter coordinates: The location coordinates
    /// - Returns: The suggested weather API to use
    func suggestWeatherAPI(for coordinates: CLLocationCoordinate2D) -> WeatherAPIType {
        return isUSLocation(coordinates) ? .nws : .openWeatherMap
    }
    
    /// Get location information with reverse geocoding
    /// - Parameter coordinates: The coordinates to geocode
    /// - Returns: A publisher that emits the location information
    func getLocationInfo(for coordinates: CLLocationCoordinate2D) -> AnyPublisher<LocationInfo, Error> {
        return Future<LocationInfo, Error> { promise in
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    promise(.failure(NSError(
                        domain: "LocationValidator",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No placemark found"]
                    )))
                    return
                }
                
                let locality = placemark.locality ?? ""
                let administrativeArea = placemark.administrativeArea ?? ""
                let country = placemark.country ?? ""
                let countryCode = placemark.isoCountryCode ?? ""
                
                // Format display name based on country
                let displayName: String
                if countryCode == "US" {
                    displayName = [locality, administrativeArea].filter { !$0.isEmpty }.joined(separator: ", ")
                } else {
                    displayName = [locality, country].filter { !$0.isEmpty }.joined(separator: ", ")
                }
                
                let info = LocationInfo(
                    displayName: displayName.isEmpty ? "Unknown Location" : displayName,
                    locality: locality,
                    administrativeArea: administrativeArea,
                    country: country,
                    countryCode: countryCode,
                    isUSLocation: countryCode == "US"
                )
                
                promise(.success(info))
            }
        }
        .eraseToAnyPublisher()
    }
}

/// Weather API types supported by the app
enum WeatherAPIType {
    case nws // National Weather Service (US only)
    case openWeatherMap // OpenWeatherMap (global)
    
    var displayName: String {
        switch self {
        case .nws:
            return "National Weather Service"
        case .openWeatherMap:
            return "OpenWeatherMap"
        }
    }
}

/// Location information structure returned by geocoding
struct LocationInfo {
    let displayName: String
    let locality: String
    let administrativeArea: String
    let country: String
    let countryCode: String
    let isUSLocation: Bool
    
    var coordinates: CLLocationCoordinate2D?
}
