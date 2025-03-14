import Foundation
import Combine

extension WeatherViewModel {
    // MARK: - Alert Management
    
    /// Process received alerts from the weather service
    func processWeatherAlerts(_ alerts: [WeatherAlert]) {
        // Store alerts in view model
        self.alerts = alerts
        
        // Pass to alert service for notification handling
        WeatherAlertService.shared.processAlerts(alerts, for: weatherData.location)
    }
    
    /// Get the highest severity level from current alerts
    var highestAlertSeverity: String? {
        // Priority order: extreme > severe > moderate > minor
        let severityLevels = ["extreme", "severe", "moderate", "minor"]
        
        for severity in severityLevels {
            if alerts.contains(where: { $0.severity.lowercased() == severity }) {
                return severity
            }
        }
        
        return nil
    }
    
    /// Check if there are any active severe or extreme alerts
    var hasSevereAlerts: Bool {
        alerts.contains { 
            ["severe", "extreme"].contains($0.severity.lowercased())
        }
    }
    
    /// Get the count of alerts by severity
    func alertCount(for severity: String) -> Int {
        alerts.filter { $0.severity.lowercased() == severity.lowercased() }.count
    }
    
    /// Get all alerts for a specific severity
    func getAlerts(for severity: String) -> [WeatherAlert] {
        alerts.filter { $0.severity.lowercased() == severity.lowercased() }
    }
    
    /// Simulate a test alert (for development and testing)
    func simulateWeatherAlert() {
        WeatherAlertService.shared.simulateAlert(for: weatherData.location)
    }
    
    // MARK: - Testing Different Alert Scenarios
    
    func simulateExtremeTornado() {
        let testAlert = WeatherAlert(
            id: "tornado-\(Int(Date().timeIntervalSince1970))",
            headline: "Tornado Warning",
            description: "The National Weather Service has issued a TORNADO WARNING for your area. A severe thunderstorm capable of producing a tornado was detected near your location. TAKE COVER NOW! Move to an interior room on the lowest floor of a sturdy building. Avoid windows.",
            severity: "extreme",
            event: "Tornado Warning",
            start: Date(),
            end: Date().addingTimeInterval(1800) // 30 minutes
        )
        
        // Process just this alert
        processWeatherAlerts([testAlert])
    }
    
    func simulateFlashFlood() {
        let testAlert = WeatherAlert(
            id: "flood-\(Int(Date().timeIntervalSince1970))",
            headline: "Flash Flood Warning",
            description: "The National Weather Service has issued a FLASH FLOOD WARNING for your area. Heavy rainfall is causing or expected to cause flash flooding in the warned area. If you are in a flood-prone area, move to higher ground immediately.",
            severity: "severe",
            event: "Flash Flood Warning",
            start: Date(),
            end: Date().addingTimeInterval(3600 * 6) // 6 hours
        )
        
        // Process just this alert
        processWeatherAlerts([testAlert])
    }
    
    func simulateWinterStorm() {
        let testAlert = WeatherAlert(
            id: "winter-\(Int(Date().timeIntervalSince1970))",
            headline: "Winter Storm Warning",
            description: "The National Weather Service has issued a WINTER STORM WARNING for your area. Heavy snow and ice accumulations expected. Travel will be difficult to impossible. If you must travel, keep an extra flashlight, food, and water in your vehicle.",
            severity: "severe",
            event: "Winter Storm Warning",
            start: Date(),
            end: Date().addingTimeInterval(3600 * 24) // 24 hours
        )
        
        // Process just this alert
        processWeatherAlerts([testAlert])
    }
}
