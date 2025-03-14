import Foundation
import UserNotifications
import ActivityKit
import Combine

class WeatherAlertService {
    static let shared = WeatherAlertService()
    
    private var currentAlerts: [WeatherAlert] = []
    private var alertActivities: [String: ActivityIdentifier] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
    }
    
    // MARK: - UNUserNotificationCenter Setup
    
    func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification authorization granted")
            } else if let error = error {
                print("Notification authorization denied: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Alert Management
    
    func processAlerts(_ alerts: [WeatherAlert], for location: String) {
        // Filter new alerts - ones that weren't in the previous set
        let existingAlertIds = currentAlerts.map { $0.id }
        let newAlerts = alerts.filter { !existingAlertIds.contains($0.id) }
        
        // Handle new alerts
        for alert in newAlerts {
            // Schedule local notification
            scheduleAlertNotification(alert, for: location)
            
            // Start Live Activity if supported
            if #available(iOS 16.1, *) {
                startAlertActivity(alert, for: location)
            }
        }
        
        // Find alerts that have ended
        let newAlertIds = alerts.map { $0.id }
        let endedAlerts = currentAlerts.filter { !newAlertIds.contains($0.id) }
        
        // End activities for alerts that are no longer active
        for alert in endedAlerts {
            if #available(iOS 16.1, *) {
                endAlertActivity(alert.id)
            }
        }
        
        // Update current alerts
        currentAlerts = alerts
    }
    
    // MARK: - Local Notifications
    
    private func scheduleAlertNotification(_ alert: WeatherAlert, for location: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(alert.event) for \(location)"
        content.subtitle = alert.headline
        content.body = alert.description
        content.sound = .default
        
        // Set category for alert severity
        content.categoryIdentifier = "WEATHER_ALERT_\(alert.severity.uppercased())"
        
        // Set notification timing
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: trigger
        )
        
        // Add to notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Dynamic Island Live Activities
    
    @available(iOS 16.1, *)
    private func startAlertActivity(_ alert: WeatherAlert, for location: String) {
        // Only start activity for severe or extreme alerts
        guard ["severe", "extreme"].contains(alert.severity.lowercased()) else { return }
        
        let alertAttributes = WeatherAlertAttributes(
            alertId: alert.id,
            location: location,
            severity: alert.severity
        )
        
        let alertContent = WeatherAlertAttributes.ContentState(
            eventType: alert.event,
            headline: alert.headline,
            startTime: alert.start,
            endTime: alert.end ?? Date().addingTimeInterval(86400) // Default to 24 hours if no end time
        )
        
        do {
            let activity = try Activity.request(
                attributes: alertAttributes,
                contentState: alertContent,
                pushType: nil
            )
            
            // Store activity ID for later reference
            alertActivities[alert.id] = activity.id
            
            print("Started live activity for alert: \(alert.id)")
        } catch {
            print("Error starting live activity: \(error.localizedDescription)")
        }
    }
    
    @available(iOS 16.1, *)
    private func endAlertActivity(_ alertId: String) {
        guard let activityId = alertActivities[alertId],
              let activity = Activity<WeatherAlertAttributes>.activities.first(where: { $0.id == activityId }) else {
            return
        }
        
        // End the activity
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            alertActivities.removeValue(forKey: alertId)
            print("Ended live activity for alert: \(alertId)")
        }
    }
    
    // MARK: - Testing Functions
    
    func simulateAlert(for location: String) {
        let testAlert = WeatherAlert(
            id: "test-alert-\(Int(Date().timeIntervalSince1970))",
            headline: "Test Severe Thunderstorm Warning",
            description: "The National Weather Service has issued a Severe Thunderstorm Warning for your area. Expect heavy rain, lightning, and possible hail. Take shelter immediately.",
            severity: "severe",
            event: "Severe Thunderstorm Warning",
            start: Date(),
            end: Date().addingTimeInterval(3600) // 1 hour from now
        )
        
        // Process just this alert
        processAlerts([testAlert], for: location)
    }
}

// MARK: - Live Activity Attributes

@available(iOS 16.1, *)
struct WeatherAlertAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var eventType: String
        var headline: String
        var startTime: Date
        var endTime: Date
    }
    
    var alertId: String
    var location: String
    var severity: String
}
