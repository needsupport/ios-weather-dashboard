import SwiftUI
import Combine
import CoreLocation
import WidgetKit

class WeatherViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var weatherData = WeatherData()
    @Published var alerts: [WeatherAlert] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: String? = nil
    @Published var lastError: String? = nil  // Added missing property
    @Published var selectedDayID: String? = nil
    @Published var selectedLocation: SavedLocation?
    @Published var selectedLocationName: String? = nil  // Added missing property
    @Published var savedLocations: [SavedLocation] = []
    
    // MARK: - Preferences
    @Published var preferences = UserPreferences() {
        didSet {
            if oldValue.unit != preferences.unit {
                // Refresh data when temperature unit changes
                if let coordinates = currentLocationCoordinates() {
                    fetchWeatherData(for: coordinates)
                }
            }
            
            // Save preferences
            savePreferences()
        }
    }
    
    // MARK: - Private Properties
    private var weatherService: WeatherServiceProtocol
    private var locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "userPreferences"
    
    // MARK: - Initializer
    init(weatherService: WeatherServiceProtocol = WeatherService(), 
         locationManager: LocationManager = LocationManager.shared) {
        self.weatherService = weatherService
        self.locationManager = locationManager
        
        // Load saved preferences
        loadPreferences()
        
        // Subscribe to location updates
        setupSubscriptions()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        // Subscribe to location updates
        locationManager.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                guard let self = self else { return }
                let coordinates = self.locationManager.coordinatesString(from: location)
                self.userDefaults.set(coordinates, forKey: "lastCoordinates")
                
                // Only fetch data if we're waiting for location
                if self.isRefreshing || self.weatherData.daily.isEmpty {
                    self.fetchWeatherData(for: coordinates)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to location errors
        locationManager.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                guard let self = self else { return }
                self.error = "Location error: \(error.localizedDescription)"
                self.lastError = "Location error: \(error.localizedDescription)"
                self.isLoading = false
                self.isRefreshing = false
                
                // Try to use last saved location
                if let lastCoordinates = self.userDefaults.string(forKey: "lastCoordinates") {
                    self.fetchWeatherData(for: lastCoordinates)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to saved locations
        locationManager.$savedLocations
            .sink { [weak self] locations in
                self?.savedLocations = locations
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Location Management
    func requestLocation() {
        locationManager.requestPermission()
        locationManager.startUpdatingLocation()
    }
    
    func currentLocationCoordinates() -> String? {
        if let coordinates = locationManager.currentLocationCoordinates() {
            return coordinates
        } else if let selectedLocation = selectedLocation {
            return selectedLocation.coordinatesString()
        } else if let lastCoordinates = userDefaults.string(forKey: "lastCoordinates") {
            return lastCoordinates
        }
        return nil
    }
    
    // MARK: - Saved Locations
    func saveCurrentLocation() {
        guard let location = locationManager.currentLocation else {
            error = "Current location not available"
            return
        }
        
        locationManager.geocodeLocation(location) { [weak self] name in
            guard let self = self, let name = name else { return }
            
            let savedLocation = SavedLocation(
                id: UUID().uuidString,
                name: name,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                isFavorite: false
            )
            
            self.locationManager.saveLocation(savedLocation)
        }
    }
    
    func selectLocation(_ location: SavedLocation) {
        selectedLocation = location
        selectedLocationName = location.name  // Update selectedLocationName
        fetchWeatherData(for: location.coordinatesString())
    }
    
    func toggleFavorite(_ location: SavedLocation) {
        var updated = location
        updated.isFavorite = !location.isFavorite
        
        // Replace in the array
        if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
            savedLocations[index] = updated
            locationManager.saveLocation(updated)
        }
    }
    
    func removeLocation(_ location: SavedLocation) {
        locationManager.removeLocation(withId: location.id)
    }
    
    // MARK: - Weather Data Functions
    func fetchWeatherData(for coordinates: String) {
        isLoading = true
        error = nil
        
        weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                self.isRefreshing = false
                
                if case .failure(let error) = completion {
                    self.error = error.localizedDescription
                    self.lastError = error.localizedDescription
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                self.weatherData = weatherData
                self.alerts = alerts
                
                // If location name came from API, update selectedLocationName
                if self.selectedLocationName == nil {
                    self.selectedLocationName = weatherData.location
                }
                
                // Update widget data
                self.updateWidgetData()
                
                // Save to CoreData
                self.saveWeatherDataToCoreData()
            })
            .store(in: &cancellables)
    }
    
    func fetchWeatherData(for cityName: String) {
        isLoading = true
        error = nil
        
        weatherService.fetchWeather(for: cityName, unit: preferences.unit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                self.isRefreshing = false
                
                if case .failure(let error) = completion {
                    self.error = error.localizedDescription
                    self.lastError = error.localizedDescription
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                self.weatherData = weatherData
                self.alerts = alerts
                
                // Update selected location name
                self.selectedLocationName = weatherData.location
                
                // Update widget data
                self.updateWidgetData()
                
                // Save to CoreData
                self.saveWeatherDataToCoreData()
            })
            .store(in: &cancellables)
    }
    
    func refreshWeather() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        if let selectedLocation = selectedLocation {
            fetchWeatherData(for: selectedLocation.coordinatesString())
        } else if let coordinates = currentLocationCoordinates() {
            fetchWeatherData(for: coordinates)
        } else {
            requestLocation()
        }
    }
    
    // MARK: - Background Refresh
    func refreshAllLocationsInBackground() async throws {
        // First refresh the current/selected location
        if let selectedLocation = selectedLocation {
            let coordinates = "\(selectedLocation.latitude),\(selectedLocation.longitude)"
            try await refreshLocationInBackground(coordinates)
        } else if let coordinates = currentLocationCoordinates() {
            try await refreshLocationInBackground(coordinates)
        }
        
        // Then refresh all saved locations
        for location in savedLocations {
            if selectedLocation?.id != location.id { // Skip if already refreshed
                let coordinates = "\(location.latitude),\(location.longitude)"
                try await refreshLocationInBackground(coordinates)
            }
        }
        
        // Update widgets after all refreshes
        updateWidgetData()
    }
    
    private func refreshLocationInBackground(_ coordinates: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            weatherService.fetchWeather(for: coordinates, unit: preferences.unit)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { [weak self] (weatherData, alerts) in
                        guard let self = self else { return }
                        
                        // If this is the selected location, update the main data
                        if self.isSelectedLocation(coordinates) {
                            DispatchQueue.main.async {
                                self.weatherData = weatherData
                                self.alerts = alerts
                            }
                        }
                        
                        // Save to CoreData regardless
                        self.saveWeatherDataToCache(weatherData, for: coordinates)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func isSelectedLocation(_ coordinates: String) -> Bool {
        if let selectedLocation = selectedLocation {
            let selectedCoordinates = "\(selectedLocation.latitude),\(selectedLocation.longitude)"
            return coordinates == selectedCoordinates
        }
        return false
    }
    
    private func saveWeatherDataToCache(_ weatherData: WeatherData, for coordinates: String) {
        // Split coordinates into latitude and longitude
        let parts = coordinates.split(separator: ",")
        guard parts.count == 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]) else {
            return
        }
        
        // Find or create the location
        let locationID = "\(latitude),\(longitude)"
        let locationName = weatherData.location
        
        // Save to CoreData
        CoreDataManager.shared.saveLocation(
            name: locationName,
            latitude: latitude,
            longitude: longitude
        )
        .flatMap { locationId -> AnyPublisher<Void, Error> in
            return CoreDataManager.shared.saveWeatherData(weatherData, for: locationId)
        }
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - UI Helper Functions
    func setSelectedDay(_ id: String) {
        selectedDayID = id
    }
    
    func getTemperatureString(_ temp: Double) -> String {
        let value = preferences.unit == .celsius ? temp : (temp * 9/5) + 32
        return "\(Int(round(value)))°\(preferences.unit.rawValue)"
    }
    
    // MARK: - Weather Icon Mapping
    func getSystemIcon(from weatherCode: String) -> String {
        switch weatherCode {
        case "clear-day": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "partly-cloudy-day": return "cloud.sun.fill"
        case "partly-cloudy-night": return "cloud.moon.fill"
        case "cloudy": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "sleet": return "cloud.sleet.fill"
        case "snow": return "cloud.snow.fill"
        case "wind": return "wind"
        case "fog": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
    
    // MARK: - Preferences Management
    private func savePreferences() {
        if let encodedData = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encodedData, forKey: preferencesKey)
        }
    }
    
    private func loadPreferences() {
        if let savedData = userDefaults.data(forKey: preferencesKey),
           let decodedPreferences = try? JSONDecoder().decode(UserPreferences.self, from: savedData) {
            self.preferences = decodedPreferences
        }
    }
    
    // MARK: - Widget Integration
    func updateWidgetData() {
        guard !weatherData.daily.isEmpty else { return }
        
        // Create daily forecasts for the widget
        let dailyWidgetForecasts = weatherData.daily.prefix(7).map { forecast in
            DailyWidgetForecast(
                id: forecast.id,
                day: forecast.day,
                highTemperature: forecast.tempHigh,
                lowTemperature: forecast.tempLow,
                condition: forecast.shortForecast,
                iconName: forecast.icon,
                precipitationChance: forecast.precipitation.chance
            )
        }
        
        // Create weather widget data
        let widgetData = WeatherWidgetData(
            location: weatherData.location,
            temperature: weatherData.daily.first?.tempHigh ?? 0,
            temperatureUnit: preferences.unit.rawValue,
            condition: weatherData.daily.first?.shortForecast ?? "",
            iconName: weatherData.daily.first?.icon ?? "",
            highTemperature: weatherData.daily.first?.tempHigh ?? 0,
            lowTemperature: weatherData.daily.first?.tempLow ?? 0,
            precipitationChance: weatherData.daily.first?.precipitation.chance ?? 0,
            dailyForecasts: Array(dailyWidgetForecasts),
            lastUpdated: Date()
        )
        
        // Save to shared container for widget access
        WeatherWidgetDataProvider.shared.saveWidgetData(widgetData)
        
        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - User Preferences
extension WeatherViewModel {
    struct UserPreferences: Codable {
        enum TemperatureUnit: String, CaseIterable, Identifiable, Codable {
            case celsius = "C"
            case fahrenheit = "F"
            
            var id: Self { self }
        }
        
        var unit: TemperatureUnit = .celsius
        var showHistoricalRange = true
        var showAnomalies = false
        var showHistoricalAvg = true
    }
}

// MARK: - Widget Data Provider
class WeatherWidgetDataProvider {
    static let shared = WeatherWidgetDataProvider()
    
    private let userDefaults: UserDefaults?
    private let weatherDataKey = "weatherWidgetData"
    
    private init() {
        // Initialize with app group container
        userDefaults = UserDefaults(suiteName: "group.com.weatherapp.widget")
    }
    
    func saveWidgetData(_ data: WeatherWidgetData) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            print("Failed to encode widget data")
            return
        }
        
        userDefaults?.set(encoded, forKey: weatherDataKey)
    }
    
    func loadWidgetData() -> WeatherWidgetData? {
        guard let data = userDefaults?.data(forKey: weatherDataKey),
              let widgetData = try? JSONDecoder().decode(WeatherWidgetData.self, from: data) else {
            return nil
        }
        
        return widgetData
    }
}

// MARK: - Widget Data Models
struct WeatherWidgetData: Codable {
    let location: String
    let temperature: Double
    let temperatureUnit: String
    let condition: String
    let iconName: String
    let highTemperature: Double
    let lowTemperature: Double
    let precipitationChance: Double
    let dailyForecasts: [DailyWidgetForecast]
    let lastUpdated: Date
    
    var temperatureString: String {
        return "\(Int(round(temperature)))°\(temperatureUnit)"
    }
    
    var highTempString: String {
        return "\(Int(round(highTemperature)))°"
    }
    
    var lowTempString: String {
        return "\(Int(round(lowTemperature)))°"
    }
}

struct DailyWidgetForecast: Codable, Identifiable {
    var id: String
    let day: String
    let highTemperature: Double
    let lowTemperature: Double
    let condition: String
    let iconName: String
    let precipitationChance: Double
    
    var highTempString: String {
        return "\(Int(round(highTemperature)))°"
    }
    
    var lowTempString: String {
        return "\(Int(round(lowTemperature)))°"
    }
}
