import Foundation

// MARK: - Core Weather Data Models

/// Main container for all weather data
struct WeatherData {
    var daily: [DailyForecast] = []
    var hourly: [HourlyForecast] = []
    var location: String = ""
    var metadata: WeatherMetadata? = nil
}

/// Daily weather forecast information
struct DailyForecast: Identifiable {
    var id: String
    var day: String                 // Day name (e.g., "Monday")
    var fullDay: String             // Full day name
    var date: Date                  // Date of forecast
    var tempHigh: Double            // High temperature
    var tempLow: Double             // Low temperature
    var precipitation: Precipitation // Precipitation data
    var uvIndex: Int                // UV index value
    var wind: Wind                  // Wind data
    var icon: String                // Weather icon identifier
    var detailedForecast: String    // Detailed text forecast
    var shortForecast: String       // Short text forecast
    var humidity: Double?           // Relative humidity percentage
    var dewpoint: Double?           // Dewpoint temperature
    var pressure: Double?           // Atmospheric pressure
    var skyCover: Double?           // Cloud coverage percentage
}

/// Hourly weather forecast information
struct HourlyForecast: Identifiable {
    var id: String
    var time: String              // Time of forecast (formatted)
    var temperature: Double       // Temperature for this hour
    var icon: String              // Weather icon identifier
    var shortForecast: String     // Short text forecast
    var windSpeed: Double         // Wind speed
    var windDirection: String     // Wind direction (N, S, E, W, etc.)
    var isDaytime: Bool           // Whether this is during daylight hours
}

/// Precipitation information
struct Precipitation {
    var chance: Double            // Percentage chance of precipitation
}

/// Wind information
struct Wind {
    var speed: Double             // Wind speed value
    var direction: String          // Wind direction (N, S, E, W, etc.)
}

/// Metadata about the weather forecast
struct WeatherMetadata {
    var office: String            // Weather service office code
    var gridX: String             // Grid X coordinate (for NWS API)
    var gridY: String             // Grid Y coordinate (for NWS API)
    var timezone: String          // Timezone of forecast location
    var updated: String           // When the forecast was last updated
}

/// Weather alert information
struct WeatherAlert: Identifiable {
    var id: String
    var headline: String          // Alert headline
    var description: String       // Full alert description
    var severity: String          // Alert severity (e.g., "Severe")
    var event: String             // Event type (e.g., "Thunderstorm Warning")
    var start: Date               // Start time of the alert
    var end: Date?                // End time of the alert (if applicable)
}
