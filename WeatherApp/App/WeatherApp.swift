import SwiftUI

@main
struct WeatherApp: App {
    @StateObject private var viewModel = WeatherViewModel()
    
    init() {
        // Set up environment
        setupEnvironment()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    // Initialize CoreData and migrate from UserDefaults
                    viewModel.initializeCoreData()
                }
        }
    }
    
    private func setupEnvironment() {
        // Register for background refresh
        registerBackgroundTasks()
    }
    
    private func registerBackgroundTasks() {
        #if !WIDGET_EXTENSION
        // Register for background refresh
        if #available(iOS 16.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourcompany.weatherapp.refresh", using: nil) { task in
                self.handleAppRefresh(task: task as! BGAppRefreshTask)
            }
        }
        #endif
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleAppRefresh()
        
        // Create a task that will be canceled if the system determines that the app refresh has
        // taken too long.
        let refreshTask = Task {
            do {
                // Refresh data for all saved locations
                try await viewModel.refreshAllLocationsInBackground()
                
                // Update widgets
                WidgetCenter.shared.reloadAllTimelines()
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        // If the refresh gets canceled, cancel the task.
        task.expirationHandler = {
            refreshTask.cancel()
        }
    }
    
    private func scheduleAppRefresh() {
        if #available(iOS 16.0, *) {
            let request = BGAppRefreshTaskRequest(identifier: "com.yourcompany.weatherapp.refresh")
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
            
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                print("Could not schedule app refresh: \(error)")
            }
        }
    }
}
