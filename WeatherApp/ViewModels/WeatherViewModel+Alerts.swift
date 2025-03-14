import Foundation
import Combine

// This extension adds alert handling to the WeatherViewModel
extension WeatherViewModel {
    
    // Setup alert service
    func setupAlertService() {
        // Request notification permissions
        weatherAlertService.requestNotificationPermissions { granted in
            if !granted {
                print("Notification permissions denied. Weather alerts won't be delivered.")
            }
        }
        
        // Setup background task for alert checking
        if UserDefaults.standard.bool(forKey: "alertsEnabled") {
            weatherAlertService.configureBackgroundRefresh()
        }
    }
    
    // Enable or disable alerts
    func setAlertsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "alertsEnabled")
        
        if enabled {
            weatherAlertService.configureBackgroundRefresh()
            checkForAlerts()
        }
    }
    
    // Check for active alerts
    func checkForAlerts() {
        guard let location = locationManager.currentLocation else {
            if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
                weatherAlertService.checkForAlerts(for: lastCoordinates)
            }
            return
        }
        
        let coordinates = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        weatherAlertService.checkForAlerts(for: coordinates)
    }
    
    // Get active alerts for the current location
    func loadActiveAlerts() {
        if alerts.isEmpty {
            if weatherData.location.isEmpty {
                // No location set yet
                return
            }
            
            // Get coordinates for current location
            let coordinateString: String
            if let location = locationManager.currentLocation {
                coordinateString = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            } else if let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") {
                coordinateString = lastCoordinates
            } else {
                // No location available
                return
            }
            
            // Fetch alerts
            weatherService.fetchWeather(for: coordinateString, unit: preferences.unit)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = "Failed to load alerts: \(error.localizedDescription)"
                    }
                }, receiveValue: { [weak self] (_, alerts) in
                    self?.alerts = alerts
                })
                .store(in: &cancellables)
        }
    }
    
    // Filter alerts by severity
    func filteredAlerts(minSeverity: String = "minor") -> [WeatherAlert] {
        let severityOrder = ["minor", "moderate", "severe", "extreme"]
        
        guard let minIndex = severityOrder.firstIndex(of: minSeverity.lowercased()) else {
            return alerts
        }
        
        return alerts.filter { alert in
            if let severityIndex = severityOrder.firstIndex(of: alert.severity.lowercased()) {
                return severityIndex >= minIndex
            }
            return true
        }
    }
    
    // Check if there are any severe alerts
    var hasSevereAlerts: Bool {
        return !filteredAlerts(minSeverity: "severe").isEmpty
    }
    
    // Check if alerts are enabled
    var alertsEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "alertsEnabled")
    }
    
    // Get alert by ID
    func getAlert(id: String) -> WeatherAlert? {
        return alerts.first { $0.id == id }
    }
    
    // Mark an alert as read
    func markAlertAsRead(id: String) {
        var readAlerts = UserDefaults.standard.stringArray(forKey: "readAlerts") ?? []
        if !readAlerts.contains(id) {
            readAlerts.append(id)
            UserDefaults.standard.set(readAlerts, forKey: "readAlerts")
        }
    }
    
    // Check if an alert has been read
    func isAlertRead(id: String) -> Bool {
        let readAlerts = UserDefaults.standard.stringArray(forKey: "readAlerts") ?? []
        return readAlerts.contains(id)
    }
    
    // Clear all read alerts
    func clearReadAlerts() {
        UserDefaults.standard.removeObject(forKey: "readAlerts")
    }
    
    // Handle notification response (for App Delegate)
    func handleAlertNotification(alertID: String) {
        // Find the alert by ID
        if let alert = getAlert(id: alertID) {
            // Mark it as read
            markAlertAsRead(id: alertID)
            
            // Additional alert handling logic here
            // e.g., navigate to alert details screen
        } else {
            // Alert not found, try to fetch alerts
            loadActiveAlerts()
        }
    }
}
