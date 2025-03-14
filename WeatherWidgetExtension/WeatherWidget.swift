import WidgetKit
import SwiftUI

/// Entry for the weather widget
struct WeatherEntry: TimelineEntry {
    let date: Date
    let widgetData: WeatherWidgetData?
}

/// Provider for weather widget data
struct WeatherWidgetProvider: TimelineProvider {
    private let dataProvider = WidgetDataProvider.shared
    
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(
            date: Date(),
            widgetData: createPlaceholderData()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        // For snapshots, try to get real data but fall back to placeholder
        dataProvider.getWidgetData { widgetData in
            let entry = WeatherEntry(
                date: Date(),
                widgetData: widgetData ?? createPlaceholderData()
            )
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        dataProvider.getWidgetData { widgetData in
            let currentDate = Date()
            
            // If we have data, use it; otherwise use placeholder
            let data = widgetData ?? createPlaceholderData()
            
            // Create an entry
            let entry = WeatherEntry(
                date: currentDate,
                widgetData: data
            )
            
            // Calculate next refresh time (30 minutes by default or sooner if data is stale)
            let refreshDate = calculateNextRefreshDate(lastUpdated: data.lastUpdated)
            
            // Create timeline with the entry
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
    
    /// Create placeholder data for widget preview and initial state
    private func createPlaceholderData() -> WeatherWidgetData {
        let dailyForecasts = (0..<7).map { i in
            return DailyWidgetForecast(
                id: "day-\(i)",
                day: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][i % 7],
                highTemperature: Double(20 + i),
                lowTemperature: Double(10 + i),
                condition: ["Sunny", "Partly Cloudy", "Cloudy", "Rainy"][i % 4],
                iconName: ["sun", "cloud.sun", "cloud", "cloud.rain"][i % 4],
                precipitationChance: Double([0, 10, 30, 60][i % 4])
            )
        }
        
        return WeatherWidgetData(
            location: "San Francisco, CA",
            temperature: 22.0,
            temperatureUnit: "°F",
            condition: "Partly Cloudy",
            iconName: "cloud.sun",
            highTemperature: 24.0,
            lowTemperature: 16.0,
            precipitationChance: 20.0,
            dailyForecasts: dailyForecasts,
            lastUpdated: Date()
        )
    }
    
    /// Calculate when the widget should next refresh based on data age
    private func calculateNextRefreshDate(lastUpdated: Date) -> Date {
        let staleDuration = Date().timeIntervalSince(lastUpdated)
        
        // If data is older than 1 hour, refresh in 15 minutes
        if staleDuration > 60 * 60 {
            return Date().addingTimeInterval(15 * 60)
        }
        
        // Otherwise refresh in 30 minutes
        return Date().addingTimeInterval(30 * 60)
    }
}

/// Weather widget view
struct WeatherWidgetEntryView: View {
    var entry: WeatherWidgetProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        if let data = entry.widgetData {
            switch widgetFamily {
            case .systemSmall:
                SmallWeatherWidgetView(data: data)
            case .systemMedium:
                MediumWeatherWidgetView(data: data)
            case .systemLarge:
                LargeWeatherWidgetView(data: data)
            default:
                SmallWeatherWidgetView(data: data)
            }
        } else {
            // Placeholder if no data is available
            Text("Weather data unavailable")
                .padding()
        }
    }
}

/// Small widget layout
struct SmallWeatherWidgetView: View {
    var data: WeatherWidgetData
    
    var body: some View {
        ZStack {
            // Weather-appropriate gradient background
            weatherBackground(for: data.condition)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(data.location)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                
                HStack {
                    weatherIcon(for: data.iconName)
                        .font(.system(size: 36))
                    
                    VStack(alignment: .leading) {
                        Text(data.temperatureString)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(data.condition)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                
                Spacer()
                
                HStack {
                    Label("\(Int(data.precipitationChance))%", systemImage: "drop.fill")
                        .font(.caption2)
                    
                    Spacer()
                    
                    Label(data.highTempString, systemImage: "arrow.up")
                        .font(.caption2)
                    
                    Label(data.lowTempString, systemImage: "arrow.down")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.85))
            }
            .padding()
        }
        .widgetURL(URL(string: "weatherapp://widget?location=\(data.location.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"))
    }
}

/// Medium widget layout
struct MediumWeatherWidgetView: View {
    var data: WeatherWidgetData
    
    var body: some View {
        ZStack {
            // Weather-appropriate gradient background
            weatherBackground(for: data.condition)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.location)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(alignment: .top, spacing: 2) {
                        Text(data.temperatureString)
                            .font(.system(size: 42, weight: .medium))
                    }
                    .foregroundColor(.white)
                    
                    Text(data.condition)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        Label("\(Int(data.precipitationChance))%", systemImage: "drop.fill")
                        Label(data.highTempString, systemImage: "arrow.up")
                        Label(data.lowTempString, systemImage: "arrow.down")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // Daily forecast for next 4 days
                HStack(spacing: 12) {
                    ForEach(data.dailyForecasts.prefix(4)) { forecast in
                        VStack(spacing: 4) {
                            Text(forecast.day)
                                .font(.caption2)
                            
                            weatherIcon(for: forecast.iconName)
                                .font(.system(size: 16))
                            
                            Text(forecast.highTempString)
                                .font(.caption)
                            
                            Text(forecast.lowTempString)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        .widgetURL(URL(string: "weatherapp://widget?location=\(data.location.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"))
    }
}

/// Large widget layout
struct LargeWeatherWidgetView: View {
    var data: WeatherWidgetData
    
    var body: some View {
        ZStack {
            // Weather-appropriate gradient background
            weatherBackground(for: data.condition)
            
            VStack(alignment: .leading, spacing: 10) {
                // Current weather header
                HStack {
                    VStack(alignment: .leading) {
                        Text(data.location)
                            .font(.headline)
                        
                        Text(data.condition)
                            .font(.title3)
                    }
                    
                    Spacer()
                    
                    // Current temperature
                    HStack(alignment: .top, spacing: 2) {
                        Text(data.temperatureString)
                            .font(.system(size: 48, weight: .medium))
                    }
                }
                .foregroundColor(.white)
                
                // Weather icon
                HStack {
                    Spacer()
                    weatherIcon(for: data.iconName)
                        .font(.system(size: 80))
                    Spacer()
                }
                .foregroundColor(.white)
                
                // Weather metrics
                HStack(spacing: 20) {
                    metricView(icon: "drop.fill", title: "Precipitation", value: "\(Int(data.precipitationChance))%")
                    Spacer()
                    metricView(icon: "arrow.up", title: "High", value: data.highTempString)
                    Spacer()
                    metricView(icon: "arrow.down", title: "Low", value: data.lowTempString)
                }
                .foregroundColor(.white)
                
                Divider()
                    .background(Color.white.opacity(0.5))
                
                // 7-day forecast
                ForEach(data.dailyForecasts.prefix(7)) { forecast in
                    HStack {
                        Text(forecast.day)
                            .frame(width: 40, alignment: .leading)
                        
                        weatherIcon(for: forecast.iconName)
                            .font(.system(size: 16))
                            .frame(width: 30)
                        
                        if forecast.precipitationChance > 0 {
                            Label("\(Int(forecast.precipitationChance))%", systemImage: "drop.fill")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.9))
                                .frame(width: 60, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(width: 60)
                        }
                        
                        Spacer()
                        
                        Text(forecast.highTempString)
                            .frame(width: 40, alignment: .trailing)
                        
                        Text(forecast.lowTempString)
                            .frame(width: 40, alignment: .trailing)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Updated: \(data.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
        }
        .widgetURL(URL(string: "weatherapp://widget?location=\(data.location.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"))
    }
}

/// Helper Views and Functions

/// Helper for creating metric view items
func metricView(icon: String, title: String, value: String) -> some View {
    VStack {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            
            Text(title)
                .font(.caption)
        }
        .foregroundColor(.white.opacity(0.8))
        
        Text(value)
            .font(.headline)
            .foregroundColor(.white)
    }
}

/// Weather icon based on condition type
@ViewBuilder
func weatherIcon(for iconType: String) -> some View {
    let iconName = mapToSystemIcon(iconType)
    Image(systemName: iconName)
        .symbolRenderingMode(.multicolor)
}

/// Map weather API icon name to SF Symbol name
func mapToSystemIcon(_ apiIconName: String) -> String {
    switch apiIconName {
    case "clear-day", "sunny":
        return "sun.max.fill"
    case "clear-night":
        return "moon.stars.fill"
    case "partly-cloudy-day", "cloud.sun":
        return "cloud.sun.fill"
    case "partly-cloudy-night":
        return "cloud.moon.fill"
    case "cloudy", "cloud":
        return "cloud.fill"
    case "rain", "cloud.rain":
        return "cloud.rain.fill"
    case "sleet":
        return "cloud.sleet.fill"
    case "snow", "cloud.snow":
        return "cloud.snow.fill"
    case "wind":
        return "wind"
    case "fog":
        return "cloud.fog.fill"
    default:
        return "cloud.fill"
    }
}

/// Create weather-appropriate background
func weatherBackground(for condition: String) -> LinearGradient {
    let isDaytime = Calendar.current.component(.hour, from: Date()) >= 6 && Calendar.current.component(.hour, from: Date()) < 20
    
    let colors: [Color]
    
    if condition.contains("clear") || condition.contains("sunny") {
        colors = isDaytime ? 
            [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.0, green: 0.5, blue: 0.9)] :
            [Color(red: 0.1, green: 0.2, blue: 0.5), Color(red: 0.0, green: 0.0, blue: 0.3)]
    } else if condition.contains("cloud") {
        colors = isDaytime ?
            [Color(red: 0.6, green: 0.7, blue: 0.9), Color(red: 0.4, green: 0.5, blue: 0.7)] :
            [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.1, blue: 0.2)]
    } else if condition.contains("rain") {
        colors = [Color(red: 0.3, green: 0.3, blue: 0.5), Color(red: 0.1, green: 0.1, blue: 0.3)]
    } else if condition.contains("snow") {
        colors = [Color(red: 0.7, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.5, blue: 0.7)]
    } else {
        colors = isDaytime ?
            [Color(red: 0.5, green: 0.6, blue: 0.8), Color(red: 0.3, green: 0.4, blue: 0.6)] :
            [Color(red: 0.2, green: 0.2, blue: 0.4), Color(red: 0.1, green: 0.1, blue: 0.2)]
    }
    
    return LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
}

/// Widget configuration
struct WeatherWidget: Widget {
    private let kind = "WeatherWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherWidgetProvider()) { entry in
            WeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("Shows current weather conditions and forecast.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Preview provider for the widget
struct WeatherWidget_Previews: PreviewProvider {
    static var previews: some View {
        let placeholderData = WeatherWidgetData(
            location: "San Francisco, CA",
            temperature: 22.0,
            temperatureUnit: "°F",
            condition: "Partly Cloudy",
            iconName: "cloud.sun",
            highTemperature: 24.0,
            lowTemperature: 16.0,
            precipitationChance: 20.0,
            dailyForecasts: (0..<7).map { i in
                return DailyWidgetForecast(
                    id: "day-\(i)",
                    day: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][i % 7],
                    highTemperature: Double(20 + i),
                    lowTemperature: Double(10 + i),
                    condition: ["Sunny", "Partly Cloudy", "Cloudy", "Rainy"][i % 4],
                    iconName: ["sun", "cloud.sun", "cloud", "cloud.rain"][i % 4],
                    precipitationChance: Double([0, 10, 30, 60][i % 4])
                )
            },
            lastUpdated: Date()
        )
        
        Group {
            WeatherWidgetEntryView(entry: WeatherEntry(
                date: Date(),
                widgetData: placeholderData
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            WeatherWidgetEntryView(entry: WeatherEntry(
                date: Date(),
                widgetData: placeholderData
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            WeatherWidgetEntryView(entry: WeatherEntry(
                date: Date(),
                widgetData: placeholderData
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}