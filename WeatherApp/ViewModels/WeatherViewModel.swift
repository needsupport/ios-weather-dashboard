import SwiftUI
import Combine
import CoreLocation

class WeatherViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var weatherData = WeatherData()
    @Published var alerts: [WeatherAlert] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: String? = nil
    @Published var selectedDayID: String? = nil
    @Published var selectedLocation: SavedLocation?
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
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                self.weatherData = weatherData
                self.alerts = alerts
                
                // Update widget data if available in this app version
                self.updateWidgetData()
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
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                self.weatherData = weatherData
                self.alerts = alerts
                
                // Update widget data
                self.updateWidgetData()
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
    private func updateWidgetData() {
        // This is just a placeholder - will be implemented when we add widget support
        // Later, we'll use WeatherWidgetDataProvider to share data with widgets
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
