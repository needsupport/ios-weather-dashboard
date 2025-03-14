import Foundation
import CoreData
import Combine

/// Manages Core Data operations for the Weather app
class CoreDataManager {
    static let shared = CoreDataManager()
    
    private let persistentContainer: NSPersistentContainer
    
    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// Background context for async operations
    var backgroundContext: NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "Weather")
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Weather Data Operations
    
    /// Saves weather data for a location
    /// - Parameters:
    ///   - weatherData: The weather data to save
    ///   - locationId: The ID of the location
    /// - Returns: Publisher that emits when operation completes
    func saveWeatherData(_ weatherData: WeatherData, for locationId: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            self.backgroundContext.perform {
                do {
                    // Find or create location entity
                    let locationFetchRequest: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()
                    locationFetchRequest.predicate = NSPredicate(format: "id == %@", locationId)
                    
                    let locations = try self.backgroundContext.fetch(locationFetchRequest)
                    let locationEntity = locations.first ?? LocationEntity(context: self.backgroundContext)
                    
                    // Find or create weather data entity
                    let weatherDataFetchRequest: NSFetchRequest<WeatherDataEntity> = WeatherDataEntity.fetchRequest()
                    weatherDataFetchRequest.predicate = NSPredicate(format: "location.id == %@", locationId)
                    
                    let existingData = try self.backgroundContext.fetch(weatherDataFetchRequest)
                    
                    // If exists, delete old forecasts to avoid duplicates
                    if let existingWeatherData = existingData.first {
                        if let dailyForecasts = existingWeatherData.dailyForecasts as? Set<DailyForecastEntity> {
                            for forecast in dailyForecasts {
                                self.backgroundContext.delete(forecast)
                            }
                        }
                        
                        if let hourlyForecasts = existingWeatherData.hourlyForecasts as? Set<HourlyForecastEntity> {
                            for forecast in hourlyForecasts {
                                self.backgroundContext.delete(forecast)
                            }
                        }
                        
                        if let alerts = existingWeatherData.alerts as? Set<WeatherAlertEntity> {
                            for alert in alerts {
                                self.backgroundContext.delete(alert)
                            }
                        }
                        
                        self.backgroundContext.delete(existingWeatherData)
                    }
                    
                    // Create new weather data entity
                    let weatherDataEntity = WeatherDataEntity(context: self.backgroundContext)
                    weatherDataEntity.id = UUID().uuidString
                    weatherDataEntity.locationName = weatherData.location
                    weatherDataEntity.updated = Date()
                    weatherDataEntity.location = locationEntity
                    
                    // Create daily forecasts
                    for forecast in weatherData.daily {
                        let forecastEntity = DailyForecastEntity(context: self.backgroundContext)
                        forecastEntity.id = forecast.id
                        forecastEntity.day = forecast.day
                        forecastEntity.fullDay = forecast.fullDay
                        forecastEntity.date = forecast.date
                        forecastEntity.tempHigh = forecast.tempHigh
                        forecastEntity.tempLow = forecast.tempLow
                        forecastEntity.precipChance = forecast.precipitation.chance
                        forecastEntity.uvIndex = Int16(forecast.uvIndex)
                        forecastEntity.icon = forecast.icon
                        forecastEntity.detailedForecast = forecast.detailedForecast
                        forecastEntity.shortForecast = forecast.shortForecast
                        forecastEntity.humidity = forecast.humidity ?? 0
                        forecastEntity.dewpoint = forecast.dewpoint ?? 0
                        forecastEntity.pressure = forecast.pressure ?? 0
                        forecastEntity.skyCover = forecast.skyCover ?? 0
                        forecastEntity.windSpeed = forecast.wind.speed
                        forecastEntity.windDirection = forecast.wind.direction
                        
                        forecastEntity.weatherData = weatherDataEntity
                    }
                    
                    // Create hourly forecasts
                    for forecast in weatherData.hourly {
                        let forecastEntity = HourlyForecastEntity(context: self.backgroundContext)
                        forecastEntity.id = forecast.id
                        forecastEntity.time = forecast.time
                        forecastEntity.date = Date() // Parse from time string
                        forecastEntity.temperature = forecast.temperature
                        forecastEntity.icon = forecast.icon
                        forecastEntity.shortForecast = forecast.shortForecast
                        forecastEntity.windSpeed = forecast.windSpeed
                        forecastEntity.windDirection = forecast.windDirection
                        forecastEntity.isDaytime = forecast.isDaytime
                        
                        forecastEntity.weatherData = weatherDataEntity
                    }
                    
                    // Create metadata if exists
                    if let metadata = weatherData.metadata {
                        let metadataEntity = WeatherMetadataEntity(context: self.backgroundContext)
                        metadataEntity.office = metadata.office
                        metadataEntity.gridX = metadata.gridX
                        metadataEntity.gridY = metadata.gridY
                        metadataEntity.timezone = metadata.timezone
                        metadataEntity.updated = metadata.updated
                        
                        metadataEntity.weatherData = weatherDataEntity
                    }
                    
                    try self.backgroundContext.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Fetches weather data for a location
    /// - Parameter locationId: The ID of the location
    /// - Returns: Publisher that emits the weather data or error
    func fetchWeatherData(for locationId: String) -> AnyPublisher<WeatherData?, Error> {
        return Future<WeatherData?, Error> { promise in
            self.backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<WeatherDataEntity> = WeatherDataEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "location.id == %@", locationId)
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    
                    if let weatherDataEntity = results.first {
                        let weatherData = self.convertToWeatherData(from: weatherDataEntity)
                        promise(.success(weatherData))
                    } else {
                        promise(.success(nil))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Location Operations
    
    /// Saves a location
    /// - Parameters:
    ///   - name: Location name
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    ///   - isFavorite: Whether this is a favorite location
    /// - Returns: Publisher that emits the location ID or error
    func saveLocation(name: String, latitude: Double, longitude: Double, isFavorite: Bool = false) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            self.backgroundContext.perform {
                do {
                    // Check if location already exists
                    let fetchRequest: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "latitude == %f AND longitude == %f", latitude, longitude)
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    
                    let locationEntity: LocationEntity
                    
                    if let existingLocation = results.first {
                        // Update existing location
                        locationEntity = existingLocation
                        locationEntity.name = name
                        locationEntity.isFavorite = isFavorite
                    } else {
                        // Create new location
                        locationEntity = LocationEntity(context: self.backgroundContext)
                        locationEntity.id = UUID().uuidString
                        locationEntity.name = name
                        locationEntity.latitude = latitude
                        locationEntity.longitude = longitude
                        locationEntity.isFavorite = isFavorite
                    }
                    
                    locationEntity.lastUpdated = Date()
                    
                    try self.backgroundContext.save()
                    promise(.success(locationEntity.id!))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Fetches all saved locations
    /// - Returns: Publisher that emits the locations or error
    func fetchAllLocations() -> AnyPublisher<[LocationInfo], Error> {
        return Future<[LocationInfo], Error> { promise in
            self.backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    
                    let locations = results.map { entity -> LocationInfo in
                        return LocationInfo(
                            id: entity.id!,
                            name: entity.name!,
                            latitude: entity.latitude,
                            longitude: entity.longitude,
                            isFavorite: entity.isFavorite,
                            lastUpdated: entity.lastUpdated!
                        )
                    }
                    
                    promise(.success(locations))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Deletes a location
    /// - Parameter locationId: ID of the location to delete
    /// - Returns: Publisher that emits when operation completes
    func deleteLocation(with locationId: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            self.backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", locationId)
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    
                    if let locationEntity = results.first {
                        self.backgroundContext.delete(locationEntity)
                        try self.backgroundContext.save()
                    }
                    
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    /// Converts a WeatherDataEntity to WeatherData model
    /// - Parameter entity: The Core Data entity
    /// - Returns: The app model
    private func convertToWeatherData(from entity: WeatherDataEntity) -> WeatherData {
        var weatherData = WeatherData()
        weatherData.location = entity.locationName ?? ""
        
        // Convert daily forecasts
        if let dailyEntities = entity.dailyForecasts as? Set<DailyForecastEntity> {
            weatherData.daily = dailyEntities.map { entity -> DailyForecast in
                let precipitation = Precipitation(chance: entity.precipChance)
                let wind = Wind(speed: entity.windSpeed, direction: entity.windDirection ?? "")
                
                return DailyForecast(
                    id: entity.id ?? UUID().uuidString,
                    day: entity.day ?? "",
                    fullDay: entity.fullDay ?? "",
                    date: entity.date ?? Date(),
                    tempHigh: entity.tempHigh,
                    tempLow: entity.tempLow,
                    precipitation: precipitation,
                    uvIndex: Int(entity.uvIndex),
                    wind: wind,
                    icon: entity.icon ?? "",
                    detailedForecast: entity.detailedForecast ?? "",
                    shortForecast: entity.shortForecast ?? "",
                    humidity: entity.humidity,
                    dewpoint: entity.dewpoint,
                    pressure: entity.pressure,
                    skyCover: entity.skyCover
                )
            }.sorted { $0.date < $1.date }
        }
        
        // Convert hourly forecasts
        if let hourlyEntities = entity.hourlyForecasts as? Set<HourlyForecastEntity> {
            weatherData.hourly = hourlyEntities.map { entity -> HourlyForecast in
                return HourlyForecast(
                    id: entity.id ?? UUID().uuidString,
                    time: entity.time ?? "",
                    temperature: entity.temperature,
                    icon: entity.icon ?? "",
                    shortForecast: entity.shortForecast ?? "",
                    windSpeed: entity.windSpeed,
                    windDirection: entity.windDirection ?? "",
                    isDaytime: entity.isDaytime
                )
            }.sorted { $0.id < $1.id }
        }
        
        // Convert metadata
        if let metadataEntity = entity.metadata {
            weatherData.metadata = WeatherMetadata(
                office: metadataEntity.office ?? "",
                gridX: metadataEntity.gridX ?? "",
                gridY: metadataEntity.gridY ?? "",
                timezone: metadataEntity.timezone ?? "",
                updated: metadataEntity.updated ?? ""
            )
        }
        
        return weatherData
    }
}

/// Simple struct to hold location information
struct LocationInfo: Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let isFavorite: Bool
    let lastUpdated: Date
}
