import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    // Use WeatherCacheService to get data
    let weatherCacheService = WeatherCacheService()
    
    func placeholder(in context: Context) -> WeatherEntry {
        // Return mock data for placeholder
        return WeatherEntry(date: Date(), location: "San Francisco", temperature: 72, condition: "sunny", high: 75, low: 65)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        // Return snapshot data (either latest cache or mock)
        let entry: WeatherEntry
        
        if let cachedData = getSavedWeatherData() {
            entry = cachedData
        } else {
            entry = WeatherEntry(date: Date(), location: "San Francisco", temperature: 72, condition: "sunny", high: 75, low: 65)
        }
        
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        // Get data from cache
        if let entry = getSavedWeatherData() {
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        } else {
            // Fallback to mock data
            let entry = WeatherEntry(date: currentDate, location: "San Francisco", temperature: 72, condition: "sunny", high: 75, low: 65)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
    
    // Helper method to get weather data from cache
    private func getSavedWeatherData() -> WeatherEntry? {
        let userDefaults = UserDefaults(suiteName: "group.com.yourcompany.weatherapp")
        
        // Try to get last used location
        guard let locationName = userDefaults?.string(forKey: "lastLocationName") else {
            return nil
        }
        
        // Try to get cached data for this location
        guard let cachedData = weatherCacheService.loadCachedData(for: locationName) else {
            return nil
        }
        
        // Create entry from cached data
        guard let todayForecast = cachedData.daily.first else {
            return nil
        }
        
        return WeatherEntry(
            date: Date(),
            location: cachedData.location,
            temperature: Int(todayForecast.tempHigh),
            condition: todayForecast.shortForecast.lowercased(),
            high: Int(todayForecast.tempHigh),
            low: Int(todayForecast.tempLow)
        )
    }
}

struct WeatherEntry: TimelineEntry {
    let date: Date
    let location: String
    let temperature: Int
    let condition: String
    let high: Int
    let low: Int
}

struct WeatherWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.5), .blue.opacity(0.2)]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(alignment: .leading) {
                // Location
                Text(entry.location)
                    .font(.system(size: family == .systemSmall ? 12 : 14, weight: .medium))
                    .lineLimit(1)
                
                if family != .systemSmall {
                    Spacer()
                }
                
                HStack(alignment: .center) {
                    // Weather icon
                    Image(systemName: weatherIcon(for: entry.condition))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: family == .systemSmall ? 30 : 40))
                    
                    Spacer()
                    
                    // Temperature
                    VStack(alignment: .trailing) {
                        Text("\(entry.temperature)°")
                            .font(.system(size: family == .systemSmall ? 28 : 34, weight: .bold))
                        
                        if family != .systemSmall {
                            // High/Low
                            Text("H:\(entry.high)° L:\(entry.low)°")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if family != .systemSmall {
                    Spacer()
                    
                    // Condition text
                    Text(entry.condition.capitalized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding()
        }
    }
    
    // Map condition to SF Symbol
    func weatherIcon(for condition: String) -> String {
        if condition.contains("clear") || condition.contains("sunny") {
            return "sun.max.fill"
        } else if condition.contains("partly cloudy") || condition.contains("mostly sunny") {
            return "cloud.sun.fill"
        } else if condition.contains("cloudy") || condition.contains("overcast") {
            return "cloud.fill"
        } else if condition.contains("rain") || condition.contains("shower") {
            return "cloud.rain.fill"
        } else if condition.contains("thunderstorm") || condition.contains("tstorm") {
            return "cloud.bolt.rain.fill"
        } else if condition.contains("snow") || condition.contains("flurries") {
            return "cloud.snow.fill"
        } else if condition.contains("fog") || condition.contains("haze") {
            return "cloud.fog.fill"
        } else if condition.contains("wind") {
            return "wind"
        }
        return "cloud.fill" // Default
    }
}

struct WeatherWidget: Widget {
    let kind: String = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("View current weather conditions")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeatherLockScreenWidget: Widget {
    let kind: String = "WeatherLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("View current weather on lock screen")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct LockScreenWidgetView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .accessoryCircular {
            CircularWidgetView(entry: entry)
        } else {
            RectangularWidgetView(entry: entry)
        }
    }
}

struct CircularWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            Gauge(value: Double(entry.temperature), in: -10...100) {
                Image(systemName: weatherIcon(for: entry.condition))
                    .symbolRenderingMode(.multicolor)
            }
            .gaugeStyle(.accessoryCircular)
            
            Text("\(entry.temperature)°")
                .font(.system(size: 16, weight: .bold))
                .offset(y: 12)
        }
    }
    
    // Map condition to SF Symbol
    func weatherIcon(for condition: String) -> String {
        if condition.contains("clear") || condition.contains("sunny") {
            return "sun.max.fill"
        } else if condition.contains("partly cloudy") || condition.contains("mostly sunny") {
            return "cloud.sun.fill"
        } else if condition.contains("cloudy") || condition.contains("overcast") {
            return "cloud.fill"
        } else if condition.contains("rain") || condition.contains("shower") {
            return "cloud.rain.fill"
        } else if condition.contains("thunderstorm") || condition.contains("tstorm") {
            return "cloud.bolt.rain.fill"
        } else if condition.contains("snow") || condition.contains("flurries") {
            return "cloud.snow.fill"
        } else if condition.contains("fog") || condition.contains("haze") {
            return "cloud.fog.fill"
        } else if condition.contains("wind") {
            return "wind"
        }
        return "cloud.fill" // Default
    }
}

struct RectangularWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack {
            Image(systemName: weatherIcon(for: entry.condition))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 22))
            
            VStack(alignment: .leading) {
                Text(entry.location)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                
                Text("\(entry.temperature)° | H:\(entry.high)° L:\(entry.low)°")
                    .font(.system(size: 10))
            }
        }
        .padding(.horizontal, 4)
    }
    
    // Map condition to SF Symbol
    func weatherIcon(for condition: String) -> String {
        if condition.contains("clear") || condition.contains("sunny") {
            return "sun.max.fill"
        } else if condition.contains("partly cloudy") || condition.contains("mostly sunny") {
            return "cloud.sun.fill"
        } else if condition.contains("cloudy") || condition.contains("overcast") {
            return "cloud.fill"
        } else if condition.contains("rain") || condition.contains("shower") {
            return "cloud.rain.fill"
        } else if condition.contains("thunderstorm") || condition.contains("tstorm") {
            return "cloud.bolt.rain.fill"
        } else if condition.contains("snow") || condition.contains("flurries") {
            return "cloud.snow.fill"
        } else if condition.contains("fog") || condition.contains("haze") {
            return "cloud.fog.fill"
        } else if condition.contains("wind") {
            return "wind"
        }
        return "cloud.fill" // Default
    }
}

struct WeatherWidget_Previews: PreviewProvider {
    static var previews: some View {
        WeatherWidgetEntryView(entry: WeatherEntry(
            date: Date(),
            location: "San Francisco, CA",
            temperature: 72,
            condition: "partly cloudy",
            high: 75,
            low: 65
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        
        WeatherWidgetEntryView(entry: WeatherEntry(
            date: Date(),
            location: "San Francisco, CA",
            temperature: 72,
            condition: "partly cloudy",
            high: 75,
            low: 65
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
        
        LockScreenWidgetView(entry: WeatherEntry(
            date: Date(),
            location: "San Francisco, CA",
            temperature: 72,
            condition: "partly cloudy",
            high: 75,
            low: 65
        ))
        .previewContext(WidgetPreviewContext(family: .accessoryCircular))
        
        LockScreenWidgetView(entry: WeatherEntry(
            date: Date(),
            location: "San Francisco, CA",
            temperature: 72,
            condition: "partly cloudy",
            high: 75,
            low: 65
        ))
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
