import Foundation
import CoreData
import Combine
import CoreLocation

/// A CoreData manager for persistent storage of weather data
/// This provides an improved alternative to UserDefaults for storing larger datasets
class WeatherCoreDataManager {
    
    // MARK: - Properties
    
    static let shared = WeatherCoreDataManager()
    
    private let container: NSPersistentContainer
    private let containerName = "WeatherData"
    
    // MARK: - Initialization
    
    private init() {
        // Create CoreData model programmatically if not using a .xcdatamodeld file
        let model = createWeatherDataModel()
        container = NSPersistentContainer(name: containerName, managedObjectModel: model)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading CoreData: \(error.localizedDescription)")
            }
        }
        
        // Merge policy to handle conflicts
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Core Data Model Creation
    
    private func createWeatherDataModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // MARK: WeatherLocation Entity
        
        let weatherLocationEntity = NSEntityDescription()
        weatherLocationEntity.name = "WeatherLocation"
        weatherLocationEntity.managedObjectClassName = "WeatherLocationEntity"
        
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType
        idAttribute.isOptional = false
        
        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = "name"
        nameAttribute.attributeType = .stringAttributeType
        nameAttribute.isOptional = false
        
        let latitudeAttribute = NSAttributeDescription()
        latitudeAttribute.name = "latitude"
        latitudeAttribute.attributeType = .doubleAttributeType
        latitudeAttribute.isOptional = false
        
        let longitudeAttribute = NSAttributeDescription()
        longitudeAttribute.name = "longitude"
        longitudeAttribute.attributeType = .doubleAttributeType
        longitudeAttribute.isOptional = false
        
        let isFavoriteAttribute = NSAttributeDescription()
        isFavoriteAttribute.name = "isFavorite"
        isFavoriteAttribute.attributeType = .booleanAttributeType
        isFavoriteAttribute.isOptional = false
        
        let lastUpdatedAttribute = NSAttributeDescription()
        lastUpdatedAttribute.name = "lastUpdated"
        lastUpdatedAttribute.attributeType = .dateAttributeType
        lastUpdatedAttribute.isOptional = true
        
        // MARK: WeatherData Entity
        
        let weatherDataEntity = NSEntityDescription()
        weatherDataEntity.name = "WeatherData"
        weatherDataEntity.managedObjectClassName = "WeatherDataEntity"
        
        let locationIdAttribute = NSAttributeDescription()
        locationIdAttribute.name = "locationId"
        locationIdAttribute.attributeType = .stringAttributeType
        locationIdAttribute.isOptional = false
        
        let dataTypeAttribute = NSAttributeDescription()
        dataTypeAttribute.name = "dataType"
        dataTypeAttribute.attributeType = .stringAttributeType
        dataTypeAttribute.isOptional = false
        
        let jsonDataAttribute = NSAttributeDescription()
        jsonDataAttribute.name = "jsonData"
        jsonDataAttribute.attributeType = .binaryDataAttributeType
        jsonDataAttribute.isOptional = false
        
        let expirationAttribute = NSAttributeDescription()
        expirationAttribute.name = "expirationDate"
        expirationAttribute.attributeType = .dateAttributeType
        expirationAttribute.isOptional = false
        
        // MARK: WeatherAlert Entity
        
        let weatherAlertEntity = NSEntityDescription()
        weatherAlertEntity.name = "WeatherAlert"
        weatherAlertEntity.managedObjectClassName = "WeatherAlertEntity"
        
        let alertIdAttribute = NSAttributeDescription()
        alertIdAttribute.name = "id"
        alertIdAttribute.attributeType = .stringAttributeType
        alertIdAttribute.isOptional = false
        
        let alertLocationIdAttribute = NSAttributeDescription()
        alertLocationIdAttribute.name = "locationId"
        alertLocationIdAttribute.attributeType = .stringAttributeType
        alertLocationIdAttribute.isOptional = false
        
        let headlineAttribute = NSAttributeDescription()
        headlineAttribute.name = "headline"
        headlineAttribute.attributeType = .stringAttributeType
        headlineAttribute.isOptional = false
        
        let descriptionAttribute = NSAttributeDescription()
        descriptionAttribute.name = "alertDescription"
        descriptionAttribute.attributeType = .stringAttributeType
        descriptionAttribute.isOptional = false
        
        let severityAttribute = NSAttributeDescription()
        severityAttribute.name = "severity"
        severityAttribute.attributeType = .stringAttributeType
        severityAttribute.isOptional = false
        
        let startAttribute = NSAttributeDescription()
        startAttribute.name = "startDate"
        startAttribute.attributeType = .dateAttributeType
        startAttribute.isOptional = false
        
        let endAttribute = NSAttributeDescription()
        endAttribute.name = "endDate"
        endAttribute.attributeType = .dateAttributeType
        endAttribute.isOptional = true
        
        let eventAttribute = NSAttributeDescription()
        eventAttribute.name = "event"
        eventAttribute.attributeType = .stringAttributeType
        eventAttribute.isOptional = false
        
        // MARK: Relationships
        
        // Location-to-WeatherData relationship (one-to-many)
        let locationToDataRelationship = NSRelationshipDescription()
        locationToDataRelationship.name = "weatherData"
        locationToDataRelationship.destinationEntity = weatherDataEntity
        locationToDataRelationship.isOptional = true
        locationToDataRelationship.deleteRule = .cascadeDeleteRule
        locationToDataRelationship.minCount = 0
        locationToDataRelationship.maxCount = 0 // 0 means "to-many"
        
        // WeatherData-to-Location relationship (many-to-one)
        let dataToLocationRelationship = NSRelationshipDescription()
        dataToLocationRelationship.name = "location"
        dataToLocationRelationship.destinationEntity = weatherLocationEntity
        dataToLocationRelationship.isOptional = false
        dataToLocationRelationship.deleteRule = .nullifyDeleteRule
        dataToLocationRelationship.minCount = 1
        dataToLocationRelationship.maxCount = 1
        
        // Location-to-Alerts relationship (one-to-many)
        let locationToAlertsRelationship = NSRelationshipDescription()
        locationToAlertsRelationship.name = "alerts"
        locationToAlertsRelationship.destinationEntity = weatherAlertEntity
        locationToAlertsRelationship.isOptional = true
        locationToAlertsRelationship.deleteRule = .cascadeDeleteRule
        locationToAlertsRelationship.minCount = 0
        locationToAlertsRelationship.maxCount = 0 // 0 means "to-many"
        
        // Alert-to-Location relationship (many-to-one)
        let alertToLocationRelationship = NSRelationshipDescription()
        alertToLocationRelationship.name = "location"
        alertToLocationRelationship.destinationEntity = weatherLocationEntity
        alertToLocationRelationship.isOptional = false
        alertToLocationRelationship.deleteRule = .nullifyDeleteRule
        alertToLocationRelationship.minCount = 1
        alertToLocationRelationship.maxCount = 1
        
        // Inverse relationships
        locationToDataRelationship.inverseRelationship = dataToLocationRelationship
        dataToLocationRelationship.inverseRelationship = locationToDataRelationship
        
        locationToAlertsRelationship.inverseRelationship = alertToLocationRelationship
        alertToLocationRelationship.inverseRelationship = locationToAlertsRelationship
        
        // Set attributes for each entity
        weatherLocationEntity.properties = [
            idAttribute, 
            nameAttribute, 
            latitudeAttribute, 
            longitudeAttribute, 
            isFavoriteAttribute, 
            lastUpdatedAttribute,
            locationToDataRelationship,
            locationToAlertsRelationship
        ]
        
        weatherDataEntity.properties = [
            locationIdAttribute, 
            dataTypeAttribute, 
            jsonDataAttribute, 
            expirationAttribute,
            dataToLocationRelationship
        ]
        
        weatherAlertEntity.properties = [
            alertIdAttribute,
            alertLocationIdAttribute,
            headlineAttribute,
            descriptionAttribute,
            severityAttribute,
            startAttribute,
            endAttribute,
            eventAttribute,
            alertToLocationRelationship
        ]
        
        // Add entities to model
        model.entities = [weatherLocationEntity, weatherDataEntity, weatherAlertEntity]
        
        return model
    }
    
    // MARK: - Public Methods
    
    /// Save a location to CoreData
    /// - Parameter location: The location to save
    /// - Returns: A publisher that emits when the save completes
    func saveLocation(name: String, coordinates: CLLocationCoordinate2D, isFavorite: Bool = false) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.container.performBackgroundTask { context in
                do {
                    // Check if location already exists
                    let locationId = "\(coordinates.latitude),\(coordinates.longitude)"
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WeatherLocation")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", locationId)
                    
                    let existingLocations = try context.fetch(fetchRequest)
                    
                    if let existingLocation = existingLocations.first {
                        // Update existing location
                        existingLocation.setValue(name, forKey: "name")
                        existingLocation.setValue(isFavorite, forKey: "isFavorite")
                        existingLocation.setValue(Date(), forKey: "lastUpdated")
                    } else {
                        // Create new location
                        guard let entity = NSEntityDescription.entity(forEntityName: "WeatherLocation", in: context) else {
                            promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create entity"])))
                            return
                        }
                        
                        let newLocation = NSManagedObject(entity: entity, insertInto: context)
                        newLocation.setValue(locationId, forKey: "id")
                        newLocation.setValue(name, forKey: "name")
                        newLocation.setValue(coordinates.latitude, forKey: "latitude")
                        newLocation.setValue(coordinates.longitude, forKey: "longitude")
                        newLocation.setValue(isFavorite, forKey: "isFavorite")
                        newLocation.setValue(Date(), forKey: "lastUpdated")
                    }
                    
                    try context.save()
                    promise(.success(true))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Get all saved locations
    /// - Returns: A publisher that emits a list of saved locations
    func getSavedLocations() -> AnyPublisher<[SavedLocation], Error> {
        return Future<[SavedLocation], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.container.performBackgroundTask { context in
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WeatherLocation")
                    let sortDescriptor = NSSortDescriptor(key: "lastUpdated", ascending: false)
                    fetchRequest.sortDescriptors = [sortDescriptor]
                    
                    let results = try context.fetch(fetchRequest)
                    
                    let locations = results.compactMap { object -> SavedLocation? in
                        guard let id = object.value(forKey: "id") as? String,
                              let name = object.value(forKey: "name") as? String,
                              let latitude = object.value(forKey: "latitude") as? Double,
                              let longitude = object.value(forKey: "longitude") as? Double,
                              let isFavorite = object.value(forKey: "isFavorite") as? Bool,
                              let lastUpdated = object.value(forKey: "lastUpdated") as? Date else {
                            return nil
                        }
                        
                        return SavedLocation(
                            id: id,
                            name: name,
                            coordinates: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                            isFavorite: isFavorite,
                            lastUpdated: lastUpdated
                        )
                    }
                    
                    promise(.success(locations))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Save weather data for a location
    /// - Parameters:
    ///   - locationId: The location ID to associate with the data
    ///   - dataType: The type of data (e.g. "daily", "hourly")
    ///   - data: The data to save
    ///   - expirationHours: Hours until the data expires
    /// - Returns: A publisher that emits when the save completes
    func saveWeatherData<T: Encodable>(
        locationId: String,
        dataType: String,
        data: T,
        expirationHours: Double = 1.0
    ) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.container.performBackgroundTask { context in
                do {
                    // Convert data to JSON
                    let encoder = JSONEncoder()
                    let jsonData = try encoder.encode(data)
                    
                    // Check if location exists
                    let locationFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WeatherLocation")
                    locationFetchRequest.predicate = NSPredicate(format: "id == %@", locationId)
                    
                    guard let location = try context.fetch(locationFetchRequest).first else {
                        promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location not found"])))
                        return
                    }
                    
                    // Check if data already exists
                    let dataFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WeatherData")
                    dataFetchRequest.predicate = NSPredicate(format: "locationId == %@ AND dataType == %@", locationId, dataType)
                    
                    let existingData = try context.fetch(dataFetchRequest)
                    
                    if let existingDataObject = existingData.first {
                        // Update existing data
                        existingDataObject.setValue(jsonData, forKey: "jsonData")
                        existingDataObject.setValue(Date().addingTimeInterval(expirationHours * 3600), forKey: "expirationDate")
                    } else {
                        // Create new data entry
                        guard let entity = NSEntityDescription.entity(forEntityName: "WeatherData", in: context) else {
                            promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create entity"])))
                            return
                        }
                        
                        let newData = NSManagedObject(entity: entity, insertInto: context)
                        newData.setValue(locationId, forKey: "locationId")
                        newData.setValue(dataType, forKey: "dataType")
                        newData.setValue(jsonData, forKey: "jsonData")
                        newData.setValue(Date().addingTimeInterval(expirationHours * 3600), forKey: "expirationDate")
                        newData.setValue(location, forKey: "location")
                    }
                    
                    try context.save()
                    promise(.success(true))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Get weather data for a location
    /// - Parameters:
    ///   - locationId: The location ID
    ///   - dataType: The type of data to retrieve
    ///   - includeExpired: Whether to include expired data
    /// - Returns: A publisher that emits the data or nil if not found
    func getWeatherData<T: Decodable>(
        locationId: String,
        dataType: String,
        includeExpired: Bool = false
    ) -> AnyPublisher<T?, Error> {
        return Future<T?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.container.performBackgroundTask { context in
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WeatherData")
                    var predicates = [NSPredicate(format: "locationId == %@", locationId),
                                      NSPredicate(format: "dataType == %@", dataType)]
                    
                    if !includeExpired {
                        let now = Date()
                        predicates.append(NSPredicate(format: "expirationDate > %@", now as NSDate))
                    }
                    
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                    
                    let results = try context.fetch(fetchRequest)
                    
                    if let dataObject = results.first,
                       let jsonData = dataObject.value(forKey: "jsonData") as? Data {
                        // Decode the data
                        let decoder = JSONDecoder()
                        let decodedData = try decoder.decode(T.self, from: jsonData)
                        promise(.success(decodedData))
                    } else {
                        promise(.success(nil))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Save weather alerts for a location
    /// - Parameters:
    ///   - locationId: The location ID
    ///   - alerts: The alerts to save
    /// - Returns: A publisher that emits when the save completes
    func saveWeatherAlerts(locationId: String, alerts: [WeatherAlert]) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.container.performBackgroundTask { context in
                do {
                    // Check if location exists
                    let locationFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WeatherLocation")
                    locationFetchRequest.predicate = NSPredicate(format: "id == %@", locationId)
                    
                    guard let location = try context.fetch(locationFetchRequest).first else {
                        promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location not found"])))
                        return
                    }
                    
                    // Delete old alerts for this location
                    let deleteFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "WeatherAlert")
                    deleteFetchRequest.predicate = NSPredicate(format: "locationId == %@", locationId)
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetchRequest)
                    try context.execute(deleteRequest)
                    
                    // Save new alerts
                    for alert in alerts {
                        guard let entity = NSEntityDescription.entity(forEntityName: "WeatherAlert", in: context) else {
                            continue
                        }
                        
                        let newAlert = NSManagedObject(entity: entity, insertInto: context)
                        newAlert.setValue(alert.id, forKey: "id")
                        newAlert.setValue(locationId, forKey: "locationId")
                        newAlert.setValue(alert.headline, forKey: "headline")
                        newAlert.setValue(alert.description, forKey: "alertDescription")
                        newAlert.setValue(alert.severity, forKey: "severity")
                        newAlert.setValue(alert.start, forKey: "startDate")
                        newAlert.setValue(alert.end, forKey: "endDate")
                        newAlert.setValue(alert.event, forKey: "event")
                        newAlert.setValue(location, forKey: "location")
                    }
                    
                    try context.save()
                    promise(.success(true))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Get weather alerts for a location
    /// - Parameter locationId: The location ID
    /// - Returns: A publisher that emits the alerts
    func getWeatherAlerts(locationId: String) -> AnyPublisher<[WeatherAlert], Error> {
        return Future<[WeatherAlert], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.container.performBackgroundTask { context in
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WeatherAlert")
                    fetchRequest.predicate = NSPredicate(format: "locationId == %@", locationId)
                    
                    let results = try context.fetch(fetchRequest)
                    
                    let alerts = results.compactMap { object -> WeatherAlert? in
                        guard let id = object.value(forKey: "id") as? String,
                              let headline = object.value(forKey: "headline") as? String,
                              let description = object.value(forKey: "alertDescription") as? String,
                              let severity = object.value(forKey: "severity") as? String,
                              let event = object.value(forKey: "event") as? String,
                              let start = object.value(forKey: "startDate") as? Date else {
                            return nil
                        }
                        
                        return WeatherAlert(
                            id: id,
                            headline: headline,
                            description: description,
                            severity: severity,
                            event: event,
                            start: start,
                            end: object.value(forKey: "endDate") as? Date
                        )
                    }
                    
                    promise(.success(alerts))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Delete a saved location and its associated data
    /// - Parameter locationId: The location ID to delete
    /// - Returns: A publisher that emits when the delete completes
    func deleteLocation(locationId: String) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.container.performBackgroundTask { context in
                do {
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "WeatherLocation")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", locationId)
                    
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    try context.execute(deleteRequest)
                    
                    // CoreData will cascade delete related weather data and alerts
                    try context.save()
                    promise(.success(true))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Clear all expired weather data
    /// - Returns: A publisher that emits the number of items deleted
    func clearExpiredData() -> AnyPublisher<Int, Error> {
        return Future<Int, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "WeatherCoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.container.performBackgroundTask { context in
                do {
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "WeatherData")
                    fetchRequest.predicate = NSPredicate(format: "expirationDate < %@", Date() as NSDate)
                    
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    deleteRequest.resultType = .resultTypeCount
                    
                    let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                    let deletedCount = result?.result as? Int ?? 0
                    
                    try context.save()
                    promise(.success(deletedCount))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - Helper Structures

/// Represents a saved location in CoreData
struct SavedLocation: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinates: CLLocationCoordinate2D
    let isFavorite: Bool
    let lastUpdated: Date
    
    static func == (lhs: SavedLocation, rhs: SavedLocation) -> Bool {
        return lhs.id == rhs.id
    }
}
