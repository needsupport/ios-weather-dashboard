import UIKit
import BackgroundTasks
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var weatherAlertService: WeatherAlertService?
    private let backgroundTaskIdentifier = "com.weatherdashboard.fetchWeatherAlerts"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register background fetch task
        registerBackgroundTasks()
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        // Register background fetch for weather alerts
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleWeatherAlertFetch(task: task as! BGAppRefreshTask)
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleWeatherAlertFetch()
    }
    
    private func scheduleWeatherAlertFetch() {
        // Cancel any previous task
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        
        // Create new task request
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // Minimum 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background weather alert fetch scheduled")
        } catch {
            print("Could not schedule weather alert fetch: \(error.localizedDescription)")
        }
    }
    
    private func handleWeatherAlertFetch(task: BGAppRefreshTask) {
        // Schedule the next fetch
        scheduleWeatherAlertFetch()
        
        // Create a task expiration handler
        task.expirationHandler = {
            // Cancel any ongoing work if the task is about to expire
            task.setTaskCompleted(success: false)
        }
        
        // Create alert service if needed
        if weatherAlertService == nil {
            let service = WeatherService()
            weatherAlertService = WeatherAlertService(weatherService: service)
        }
        
        // Get the last known coordinates
        guard let lastCoordinates = UserDefaults.standard.string(forKey: "lastCoordinates") else {
            task.setTaskCompleted(success: false)
            return
        }
        
        // Check for alerts
        weatherAlertService?.checkForAlerts(for: lastCoordinates)
        
        // Set task completed
        task.setTaskCompleted(success: true)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification response - e.g., navigate to alert details
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            print("User tapped notification: \(userInfo)")
            
            // You could post a notification to navigate to alert details
            NotificationCenter.default.post(
                name: Notification.Name("ShowWeatherAlert"),
                object: nil,
                userInfo: userInfo
            )
            
        case "VIEW_ACTION":
            // User tapped "View Details" action
            print("User tapped View Details: \(userInfo)")
            
            // Post notification to show alert details
            NotificationCenter.default.post(
                name: Notification.Name("ShowWeatherAlert"),
                object: nil,
                userInfo: userInfo
            )
            
        case "DISMISS_ACTION":
            // User dismissed the notification
            print("User dismissed notification: \(userInfo)")
            
        default:
            break
        }
        
        completionHandler()
    }
}
