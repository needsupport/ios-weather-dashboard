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
    
    // MARK: - Preferences
    @Published var preferences = UserPreferences()
    
    // MARK: - Private Properties
    private var weatherService: WeatherServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Services
    lazy var weatherCacheService: WeatherCacheService = {
        return WeatherCacheService()
    }()
    
    // Using the shared LocationManager instance
    var locationManager: LocationManager {
        return LocationManager.shared
    }
    
    // MARK: - Initializer
    init(weatherService: WeatherServiceProtocol = WeatherService()) {
        self.weatherService = weatherService
        setupLocationSubscriptions()
    }
    
    // MARK: - Setup Subscriptions
    private func setupLocationSubscriptions() {
        // Subscribe to location updates
        locationManager.locationUpdatePublisher
            .sink { [weak self] coordinate in
                guard let self = self else { return }
                
                // Fetch weather for this location
                let coordinateString = "\(coordinate.latitude),\(coordinate.longitude)"
                UserDefaults.standard.set(coordinateString, forKey: "lastCoordinates")
                
                self.fetchWeatherData(for: coordinateString)
            }
            .store(in: &cancellables)
        
        // Subscribe to location errors
        locationManager.locationErrorPublisher
            .sink { [weak self] error in
                guard let self = self else { return }
                
                // Update error state
                self.error = error.localizedDescription
                self.isLoading = false
                self.isRefreshing = false
                
                // Try to use last known location
                if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
                    self.fetchWeatherData(for: lastCoordinates)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Location Management
    func requestLocation() {
        locationManager.requestLocation()
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
                    
                    // Try to get any cached data as fallback
                    if let locationName = self.getLocationNameFromCoordinates(coordinates),
                       let cachedData = self.weatherCacheService.loadCachedData(for: locationName) {
                        self.weatherData = cachedData
                        self.error = "Using cached data. Error: \(error.localizedDescription)"
                    }
                }
            }, receiveValue: { [weak self] (weatherData, alerts) in
                guard let self = self else { return }
                self.weatherData = weatherData
                self.alerts = alerts
                
                // Cache the data
                self.weatherCacheService.save(weatherData: weatherData, for: weatherData.location)
            })
            .store(in: &cancellables)
    }
    
    func refreshWeather() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
            fetchWeatherData(for: lastCoordinates)
        } else {
            requestLocation()
            isRefreshing = false
        }
    }
    
    // MARK: - Helper Methods
    private func getLocationNameFromCoordinates(_ coordinates: String) -> String? {
        // Check if this location is in saved locations
        let components = coordinates.split(separator: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        
        // Find matching saved location
        for location in locationManager.savedLocations {
            if abs(location.latitude - lat) < 0.01 && abs(location.longitude - lon) < 0.01 {
                return location.name
            }
        }
        
        // Check if we have a last known location name
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates"),
           lastCoordinates == coordinates,
           let lastLocationName = UserDefaults.standard.string(forKey: "lastLocationName") {
            return lastLocationName
        }
        
        return nil
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
        case "clear-day", "sun": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "partly-cloudy-day": return "cloud.sun.fill"
        case "partly-cloudy-night": return "cloud.moon.fill"
        case "cloudy", "cloud": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "sleet": return "cloud.sleet.fill"
        case "snow": return "cloud.snow.fill"
        case "wind": return "wind"
        case "fog": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - User Preferences
extension WeatherViewModel {
    struct UserPreferences {
        enum TemperatureUnit: String, CaseIterable, Identifiable {
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
