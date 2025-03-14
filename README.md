# iOS Weather Dashboard

A comprehensive native iOS weather application built with SwiftUI that provides detailed weather forecasts, historical data comparison, and interactive visualizations.

## Features

- Current weather conditions with detailed metrics
- 7-day forecast with daily temperature ranges and conditions
- Hourly forecast with detailed breakdowns
- Weather data visualization with historical comparisons
- Interactive weather cards for each forecast day
- Location searching and current location detection
- Global location support with international weather data
- Detailed day view with extended information
- Weather alerts display
- Unit conversion (°C/°F) with regional defaults
- Responsive layout for all iOS devices
- Support for both National Weather Service API (US) and OpenWeather API (international)
- Offline mode with CoreData-based caching
- WidgetKit integration for home and lock screens

## Architecture

This project uses the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Define data structures and business logic
- **ViewModels**: Manage state, business logic, and data transformation
- **Views**: SwiftUI components that present data to the user
- **Services**: Handle API communication and data persistence

## Project Structure

```
ios-weather-dashboard/
├── WeatherApp/
│   ├── App/
│   │   ├── AppDelegate.swift          # App delegate with background processing
│   │   └── WeatherApp.swift           # Main app entry point
│   ├── Models/
│   │   ├── NWSModels.swift            # NWS API specific models
│   │   ├── Weather.xcdatamodeld       # CoreData model for persistence
│   │   └── WeatherModels.swift        # Core data structures
│   ├── ViewModels/
│   │   ├── WeatherViewModel.swift                 # Core state management
│   │   ├── WeatherViewModel+Cache.swift           # Caching functionality
│   │   ├── WeatherViewModel+CoreData.swift        # CoreData integration
│   │   ├── WeatherViewModel+Alerts.swift          # Weather alerts handling
│   │   ├── WeatherViewModel+BackgroundRefresh.swift  # Background updating 
│   │   └── WeatherViewModel+LocationIntegration.swift # Location handling
│   ├── Views/
│   │   ├── ContentView.swift              # Main container view
│   │   ├── CurrentWeatherView.swift       # Current conditions display
│   │   ├── WeatherCardView.swift          # Daily forecast card
│   │   ├── WeatherChartView.swift         # Data visualization
│   │   ├── LocationSelectorView.swift     # Location picker UI
│   │   ├── LocationManagementView.swift   # Saved locations management
│   │   ├── SavedLocationsView.swift       # Saved locations display
│   │   └── WeatherDashboardView.swift     # Main dashboard UI
│   ├── Services/
│   │   ├── WeatherService.swift           # Weather data protocol
│   │   ├── WeatherAPIService.swift        # API integration
│   │   ├── MockWeatherService.swift       # Mock data for testing
│   │   ├── CoreDataManager.swift          # Data persistence system
│   │   ├── WeatherAlertService.swift      # Alert monitoring
│   │   └── LocationManager.swift          # Location handling
│   └── Info.plist                         # App configuration
├── WeatherWidgetExtension/                # WidgetKit extension
│   ├── WeatherWidget.swift                # Home screen widget
│   ├── WeatherLockScreenWidget.swift      # Lock screen widget
│   ├── WidgetDataProvider.swift           # Data provider for widgets
│   └── Info.plist                         # Widget configuration
├── WeatherAppTests/                       # Unit tests
│   └── WeatherViewModelTests.swift        # ViewModel tests
└── Documentation/                         # Additional documentation
```

## Implementation Details

### Code Design

The application follows a reactive programming paradigm using Combine:

1. **Data Flow**:
   - ViewModels expose `@Published` properties that the Views observe
   - Data changes trigger automatic UI updates through the observation system
   - Services return `AnyPublisher` types for asynchronous operations

2. **Dependency Injection**:
   - Services are injected into ViewModels via constructors
   - This allows for easier testing and swapping of implementations

3. **Protocol-Based Design**:
   - Services implement protocols (e.g., `WeatherServiceProtocol`)
   - Enables multiple implementations (production, mock) sharing common interfaces

4. **Error Handling**:
   - Robust error system with dedicated error types and handling logic
   - Errors are propagated up and displayed in user-friendly formats
   - Fallback to cached data when network requests fail

5. **Data Persistence**:
   - CoreData-based persistence for weather data and user preferences
   - Multi-tiered caching strategy with expiration policies
   - Data migrations from legacy storage systems

### Current Status

#### Completed
- Core MVVM architecture setup
- Model definitions for weather data
- Main view implementations (current weather, cards, chart, location)
- Weather service with API integrations for US and international locations
- Location services with reliable country detection
- CoreData integration for robust data persistence
- Test suite with >85% code coverage
- User preferences system
- Location management with multiple saved locations
- Widget extension implementation
- International API integration with OpenWeather
- Background refresh implementation
- Enhanced location handling for non-US locations

#### Recent Implementations (March 2025)
- **CoreData Integration**: Replaced UserDefaults with a comprehensive CoreData persistence layer for better performance and data relationships
- **Enhanced Location Handling**: Implemented robust detection and handling of non-US locations with automatic API switching
- **Comprehensive Testing Strategy**: Added extensive unit, UI, and performance tests with >85% code coverage
- **Widget Support**: Completed full implementation of home screen and lock screen widgets

#### In Progress
- Dynamic Island integration (iOS 16+)
- Dark mode optimizations
- Advanced charts for historical data
- Push notification handling for severe weather alerts

## Development Plans

The project is being implemented in phases as outlined in the [Implementation Roadmap](https://github.com/needsupport/ios-weather-dashboard/issues/8):

1. **Phase 1**: Core Functionality - API integration and architecture improvements
2. **Phase 2**: UI Enhancements - Design system and view improvements
3. **Phase 3**: Extensions and Features - Widgets and advanced features
4. **Phase 4**: Testing and Refinement - Comprehensive testing and polishing

## Setup Instructions

### Prerequisites

- Xcode 14.0+
- iOS 15.0+ (iOS 16.0+ recommended for all features)
- Swift 5.7+
- An API key from OpenWeather (for international data)

### Configuration

1. Clone the repository:
```bash
git clone https://github.com/needsupport/ios-weather-dashboard.git
cd ios-weather-dashboard
```

2. Open the project in Xcode:
```bash
open WeatherApp.xcodeproj
```

3. Configure API keys:
   - Add your OpenWeather API key to the project
   - You can set it using the ApiKeyManager in the app:
   ```swift
   ApiKeyManager.shared.setOpenWeatherMapApiKey("YOUR_API_KEY")
   ```
   - Or add it in the ApiKeyManager initialization in WeatherAPIService.swift for development

4. Set up App Groups for Widget Support:
   - In Xcode, select the app target and go to "Signing & Capabilities"
   - Add the "App Groups" capability
   - Create a group identifier (e.g., "group.com.yourcompany.ios-weather-dashboard")
   - Do the same for the Widget Extension target
   - Update the group name in WeatherWidgetDataProvider if needed

5. Build and run the application on your device or simulator

### Using Mock Data

For development without an API key:
1. Navigate to `WeatherApp/ViewModels/WeatherViewModel.swift`
2. In the `init()` method, replace `self.weatherService = WeatherService()` with `self.weatherService = MockWeatherService()`

## Testing

The project includes comprehensive testing:

- **Unit Tests**: For ViewModels, Services, and Models
- **UI Tests**: For critical user flows
- **Performance Tests**: For measuring and tracking app performance
- **Snapshot Tests**: For verifying UI visual consistency

Run the tests to verify:
- Data fetching and error handling
- Temperature unit conversion
- Icon mapping
- Location handling including international support
- Cache expiration behavior
- CoreData operations

## Performance Optimizations

The app implements several performance optimizations:
- Lazy loading of view components
- CoreData-based persistence with optimized fetch requests
- Conditional rendering to reduce view complexity
- Efficient redrawing of chart components
- Background task management for optimal battery usage
- Batch fetching for large result sets
- Strategic denormalization for widget access

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
