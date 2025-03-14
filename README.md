# iOS Weather Dashboard

A comprehensive native iOS weather application built with SwiftUI that provides detailed weather forecasts, historical data comparison, and interactive visualizations.

## 📱 Features

- Current weather conditions display
- 7-day forecast with detailed metrics
- Hourly weather breakdowns
- Temperature, precipitation, UV index, and wind metrics
- Historical data comparison
- Clean, modern SwiftUI interface
- Responsive layout for all iOS devices
- Native iOS widgets for home and lock screens
- Dynamic Island integration
- Support for both NWS and OpenWeather APIs
- Unit conversion (Fahrenheit/Celsius)
- Geolocation support
- Offline mode with cached data

## 🏗️ Architecture

This application follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Define the data structures and business logic
- **Views**: SwiftUI components that present data to the user
- **ViewModels**: Manage state, business logic, and data transformation
- **Services**: Handle API communication and data persistence

## 📂 Project Structure

```
ios-weather-dashboard/
├── WeatherApp/
│   ├── App/
│   │   └── WeatherApp.swift       # Main app entry point
│   ├── Models/
│   │   └── WeatherModels.swift    # Core data structures
│   ├── ViewModels/
│   │   └── WeatherViewModel.swift # State management and business logic
│   ├── Views/
│   │   ├── ContentView.swift      # Main container view
│   │   ├── CurrentWeatherView.swift  # Current conditions display
│   │   ├── WeatherCardView.swift  # Individual forecast day card
│   │   ├── WeatherChartView.swift # Data visualization
│   │   └── LocationSelectorView.swift # Location picker
│   ├── Services/
│   │   └── WeatherAPIService.swift # API communication
│   └── Utilities/
│       └── WeatherUtils.swift     # Helper functions
├── WeatherWidgetExtension/
│   ├── WeatherWidget.swift        # Home screen widget
│   └── WeatherLockScreenWidget.swift # Lock screen widget
├── Screenshots/                   # App screenshots
└── Documentation/                 # Additional documentation
```

## 🚀 Getting Started

### Prerequisites

- Xcode 14.0+
- iOS 15.0+ (iOS 16.0+ recommended for all features)
- Swift 5.7+
- Active Apple Developer account (for widget testing)

### Installation

1. Clone this repository:
```bash
git clone https://github.com/needsupport/ios-weather-dashboard.git
cd ios-weather-dashboard
```

2. Open the project in Xcode:
```bash
open WeatherApp.xcodeproj
```

3. Configure the API services in `WeatherAPIService.swift`:
   - Set `baseURL` to your backend API endpoint
   - Configure API keys if using OpenWeather

4. Build and run the application on your device or simulator

## ⚙️ Configuration

### Weather API Services

The app supports two weather data providers:

1. **National Weather Service (NWS) API**
   - Free and open API from the US government
   - No API key required
   - Provides detailed forecasts for US locations only

2. **OpenWeather API**
   - Requires an API key (free tier available)
   - Global coverage
   - Configure in the app settings

### Backend Proxy Server

For production usage, a backend proxy server is recommended to:
- Secure API keys
- Implement rate limiting
- Provide caching
- Handle complex data transformation

See the [Backend Configuration Guide](Documentation/BackendConfiguration.md) for setup instructions.

## 📱 iOS-Specific Features

### Widgets

The app includes several widget types:
- **Today Widget**: Shows current conditions and temperature
- **Forecast Widget**: Displays 3-day forecast with high/low temperatures
- **Alerts Widget**: Shows active weather alerts for the user's location

### Dynamic Island

On supported devices, the app integrates with Dynamic Island to show:
- Active weather alerts
- Precipitation starting/stopping notifications
- Temperature changes
- Severe weather approaching

### Notifications

The app can send push notifications for:
- Severe weather alerts
- Significant temperature changes
- Precipitation forecasts
- Daily forecast summaries

## 📊 Data Visualization

The app includes multiple visualization types:
- Temperature curve charts
- Precipitation probability bars
- Wind direction and speed indicators
- UV index forecasts
- Historical temperature comparison

## 🔄 Data Flow

1. User selects or provides location
2. App fetches weather data from configured API
3. Data is processed and transformed for display
4. UI updates with the latest weather information
5. Data is cached for offline access

## 🔒 Security & Privacy

- All API keys are stored securely and never exposed in client code
- Location data is only used for weather forecasting
- No user data is collected or shared
- All network requests use HTTPS

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
