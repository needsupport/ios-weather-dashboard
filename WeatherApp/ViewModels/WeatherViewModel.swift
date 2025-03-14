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
    private var locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializer
    init(weatherService: WeatherServiceProtocol = WeatherService()) {
        self.weatherService = weatherService
        setupLocationManager()
    }
    
    // MARK: - Location Management
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
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
}

// MARK: - CLLocationManagerDelegate
extension WeatherViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        let coordinates = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        UserDefaults.standard.set(coordinates, forKey: "lastCoordinates")
        
        fetchWeatherData(for: coordinates)
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = "Location error: \(error.localizedDescription)"
        self.isLoading = false
        self.isRefreshing = false
        
        // Try to use last saved location if available
        if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
            fetchWeatherData(for: lastCoordinates)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            self.error = "Location access denied. Please enable it in Settings."
            // Try to use last saved location if available
            if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
                fetchWeatherData(for: lastCoordinates)
            }
        case .notDetermined:
            // Wait for user to grant permission
            break
        @unknown default:
            break
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
