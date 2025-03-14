import WidgetKit
import SwiftUI

/// Entry for the weather widget
struct WeatherEntry: TimelineEntry {
    let date: Date
    let location: String
    let temperature: Double
    let description: String
    let icon: String
    let precipitation: Double
    let windSpeed: Double
}

/// Provider for weather widget data
struct WeatherWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(
            date: Date(),
            location: "Seattle, WA",
            temperature: 72,
            description: "Partly Cloudy",
            icon: "cloud",
            precipitation: 20,
            windSpeed: 5
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        let entry = WeatherEntry(
            date: Date(),
            location: "Seattle, WA",
            temperature: 72,
            description: "Partly Cloudy",
            icon: "cloud",
            precipitation: 20,
            windSpeed: 5
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        // In a real app, we would fetch weather data here
        // For now, just create placeholder data
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        let entry = WeatherEntry(
            date: currentDate,
            location: "Seattle, WA",
            temperature: 72,
            description: "Partly Cloudy",
            icon: "cloud",
            precipitation: 20,
            windSpeed: 5
        )
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

/// Weather widget view
struct WeatherWidgetEntryView: View {
    var entry: WeatherWidgetProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }
    
    /// Small widget layout
    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.location)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                weatherIcon(for: entry.icon)
                    .font(.system(size: 36))
                
                VStack(alignment: .leading) {
                    Text("\(Int(entry.temperature))°")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(entry.description)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack {
                Label("\(Int(entry.precipitation))%", systemImage: "drop.fill")
                    .font(.caption2)
                
                Spacer()
                
                Label("\(Int(entry.windSpeed)) mph", systemImage: "wind")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
    
    /// Medium widget layout
    var mediumWidget: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.location)
                    .font(.headline)
                
                Spacer()
                
                HStack(alignment: .top, spacing: 2) {
                    Text("\(Int(entry.temperature))")
                        .font(.system(size: 42, weight: .medium))
                    
                    Text("°F")
                        .font(.body)
                        .offset(y: 6)
                }
                
                Text(entry.description)
                    .font(.subheadline)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Label("\(Int(entry.precipitation))%", systemImage: "drop.fill")
                    Label("\(Int(entry.windSpeed)) mph", systemImage: "wind")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            weatherIcon(for: entry.icon)
                .font(.system(size: 80))
        }
        .padding()
    }
    
    /// Large widget layout
    var largeWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.location)
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .top, spacing: 2) {
                        Text("\(Int(entry.temperature))")
                            .font(.system(size: 54, weight: .medium))
                        
                        Text("°F")
                            .font(.title)
                            .offset(y: 8)
                    }
                    
                    Text(entry.description)
                        .font(.title3)
                }
                
                Spacer()
                
                weatherIcon(for: entry.icon)
                    .font(.system(size: 100))
            }
            
            Divider()
            
            // Weather metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricView(icon: "drop.fill", title: "Precipitation", value: "\(Int(entry.precipitation))%")
                metricView(icon: "wind", title: "Wind", value: "\(Int(entry.windSpeed)) mph")
                metricView(icon: "sun.max.fill", title: "UV Index", value: "5 (Moderate)")
                metricView(icon: "humidity.fill", title: "Humidity", value: "45%")
            }
            
            Spacer()
            
            Text("Updated: \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    /// Helper for creating metric view items
    func metricView(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
            }
        }
    }
    
    /// Weather icon based on condition type
    @ViewBuilder
    func weatherIcon(for iconType: String) -> some View {
        switch iconType {
        case "sun":
            Image(systemName: "sun.max.fill")
                .symbolRenderingMode(.multicolor)
        case "cloud":
            Image(systemName: "cloud.fill")
                .symbolRenderingMode(.multicolor)
        case "rain":
            Image(systemName: "cloud.rain.fill")
                .symbolRenderingMode(.multicolor)
        case "snow":
            Image(systemName: "snow")
                .symbolRenderingMode(.multicolor)
        default:
            Image(systemName: "cloud.fill")
                .symbolRenderingMode(.multicolor)
        }
    }
}

/// Widget configuration
struct WeatherWidget: Widget {
    private let kind = "WeatherWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherWidgetProvider()) { entry in
            WeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("Shows current weather conditions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WeatherWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WeatherWidgetEntryView(entry: WeatherEntry(
                date: Date(),
                location: "Seattle, WA",
                temperature: 72,
                description: "Partly Cloudy",
                icon: "cloud",
                precipitation: 20,
                windSpeed: 5
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            WeatherWidgetEntryView(entry: WeatherEntry(
                date: Date(),
                location: "Seattle, WA",
                temperature: 72,
                description: "Partly Cloudy",
                icon: "cloud",
                precipitation: 20,
                windSpeed: 5
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            WeatherWidgetEntryView(entry: WeatherEntry(
                date: Date(),
                location: "Seattle, WA",
                temperature: 72,
                description: "Partly Cloudy",
                icon: "cloud",
                precipitation: 20,
                windSpeed: 5
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}