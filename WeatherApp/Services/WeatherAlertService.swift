import Foundation
import UserNotifications
import Combine

enum AlertSeverity: String, Codable {
    case minor
    case moderate
    case severe
    case extreme
    
    var notificationSound: UNNotificationSound {
        switch self {
        case .minor, .moderate:
            return .default
        case .severe, .extreme:
            return .defaultCritical
        }
    }
    
    var notificationCategory: String {
        switch self {
        case .minor:
            return "ALERT_MINOR"
        case .moderate:
            return "ALERT_MODERATE"
        case .severe:
            return "ALERT_SEVERE"
        case .extreme:
            return "ALERT_EXTREME"
        }
    }
}

class WeatherAlertService {
    private let weatherService: WeatherServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // How often to check for alerts in the background
    private let alertPollingInterval: TimeInterval = 1800 // 30 minutes
    
    init(weatherService: WeatherServiceProtocol) {
        self.weatherService = weatherService
        setupNotificationCategories()
    }
    
    // Setup notification actions and categories
    private func setupNotificationCategories() {
        // View action - opens the app to view the alert
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View Details",
            options: .foreground
        )
        
        // Dismiss action
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: .destructive
        )
        
        // Create categories for different alert severities
        let minorCategory = UNNotificationCategory(
            identifier: AlertSeverity.minor.notificationCategory,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        let moderateCategory = UNNotificationCategory(
            identifier: AlertSeverity.moderate.notificationCategory,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        let severeCategory = UNNotificationCategory(
            identifier: AlertSeverity.severe.notificationCategory,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.hiddenPreviewsShowTitle]
        )
        
        let extremeCategory = UNNotificationCategory(
            identifier: AlertSeverity.extreme.notificationCategory,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.hiddenPreviewsShowTitle, .criticalAlert]
        )
        
        // Register categories
        notificationCenter.setNotificationCategories([
            minorCategory,
            moderateCategory,
            severeCategory,
            extremeCategory
        ])
    }
    
    // Request notification permissions
    func requestNotificationPermissions(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
                completion(false)
                return
            }
            completion(granted)
        }
    }
    
    // Check for alerts for a given location
    func checkForAlerts(for coordinates: String) {
        weatherService.fetchWeather(for: coordinates, unit: .celsius)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error fetching weather alerts: \(error.localizedDescription)")
                }
            }, receiveValue: { (_, alerts) in
                // Process and schedule notifications for new alerts
                self.processAlerts(alerts, for: coordinates)
            })
            .store(in: &cancellables)
    }
    
    // Process alerts and schedule notifications for new ones
    private func processAlerts(_ alerts: [WeatherAlert], for location: String) {
        // Get previously processed alert IDs
        let processedAlertIDs = UserDefaults.standard.stringArray(forKey: "processedAlertIDs") ?? []
        var newProcessedAlertIDs = processedAlertIDs
        
        for alert in alerts {
            // Skip if this alert has already been processed
            if processedAlertIDs.contains(alert.id) {
                continue
            }
            
            // Schedule notification for new alert
            scheduleNotification(for: alert, location: location)
            
            // Add to processed list
            newProcessedAlertIDs.append(alert.id)
        }
        
        // Update processed alert IDs in UserDefaults
        UserDefaults.standard.set(newProcessedAlertIDs, forKey: "processedAlertIDs")
    }
    
    // Schedule a notification for a weather alert
    private func scheduleNotification(for alert: WeatherAlert, location: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(alert.event) for \(location)"
        content.body = alert.description
        content.sound = getSeverity(from: alert.severity).notificationSound
        content.categoryIdentifier = getSeverity(from: alert.severity).notificationCategory
        
        // Add alert info to user info
        content.userInfo = [
            "alertID": alert.id,
            "location": location,
            "event": alert.event,
            "severity": alert.severity
        ]
        
        // Create trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "weather_alert_\(alert.id)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Convert string severity to enum
    private func getSeverity(from severityString: String) -> AlertSeverity {
        return AlertSeverity(rawValue: severityString.lowercased()) ?? .moderate
    }
    
    // Configure background refresh task
    func configureBackgroundRefresh() {
        // Setup background task - this would normally be done in AppDelegate or SceneDelegate
        let backgroundTaskIdentifier = "com.weatherapp.refreshAlerts"
        
        #if os(iOS)
        // This isn't really possible to implement fully in a code snippet
        // as it requires app configuration and AppDelegate/SceneDelegate setup
        print("Background refresh task would be configured here")
        #endif
    }
}
