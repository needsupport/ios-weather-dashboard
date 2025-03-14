import WidgetKit
import SwiftUI

/// Lock screen widget provider
struct LockScreenWidgetProvider: TimelineProvider {
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

/// Circular lock screen widget view
struct LockScreenCircularView: View {
    var entry: LockScreenWidgetProvider.Entry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack {
                // Icon
                Image(systemName: iconName(for: entry.icon))
                    .font(.system(size: 14))
                    .symbolRenderingMode(.multicolor)
                
                // Temperature
                Text("\(Int(entry.temperature))°")
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }
    
    private func iconName(for icon: String) -> String {
        switch icon {
        case "sun": return "sun.max.fill"
        case "cloud": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "snow": return "snow"
        default: return "cloud.fill"
        }
    }
}

/// Rectangular lock screen widget view
struct LockScreenRectangularView: View {
    var entry: LockScreenWidgetProvider.Entry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            HStack(spacing: 8) {
                // Icon
                Image(systemName: iconName(for: entry.icon))
                    .font(.system(size: 14))
                    .symbolRenderingMode(.multicolor)
                
                VStack(alignment: .leading) {
                    // Temperature
                    Text("\(Int(entry.temperature))°")
                        .font(.system(size: 14, weight: .bold))
                    
                    // Location
                    Text(entry.location)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func iconName(for icon: String) -> String {
        switch icon {
        case "sun": return "sun.max.fill"
        case "cloud": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "snow": return "snow"
        default: return "cloud.fill"
        }
    }
}

/// Inline lock screen widget view
struct LockScreenInlineView: View {
    var entry: LockScreenWidgetProvider.Entry
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: iconName(for: entry.icon))
                .symbolRenderingMode(.multicolor)
            
            // Temperature
            Text("\(Int(entry.temperature))°")
            
            // Description
            Text(entry.description)
        }
        .font(.system(size: 12))
    }
    
    private func iconName(for icon: String) -> String {
        switch icon {
        case "sun": return "sun.max.fill"
        case "cloud": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "snow": return "snow"
        default: return "cloud.fill"
        }
    }
}

/// Lock screen widget configuration
@available(iOSApplicationExtension 16.0, *)
struct WeatherLockScreenWidget: Widget {
    private let kind = "WeatherLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenWidgetProvider()) { entry in
            switch family {
            case .accessoryCircular:
                LockScreenCircularView(entry: entry)
            case .accessoryRectangular:
                LockScreenRectangularView(entry: entry)
            case .accessoryInline:
                LockScreenInlineView(entry: entry)
            @unknown default:
                LockScreenCircularView(entry: entry)
            }
        }
        .configurationDisplayName("Weather")
        .description("Shows current temperature and conditions.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@available(iOSApplicationExtension 16.0, *)
struct WeatherLockScreenWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LockScreenCircularView(entry: WeatherEntry(
                date: Date(),
                location: "Seattle, WA",
                temperature: 72,
                description: "Partly Cloudy",
                icon: "cloud",
                precipitation: 20,
                windSpeed: 5
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            
            LockScreenRectangularView(entry: WeatherEntry(
                date: Date(),
                location: "Seattle, WA",
                temperature: 72,
                description: "Partly Cloudy",
                icon: "cloud",
                precipitation: 20,
                windSpeed: 5
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            
            LockScreenInlineView(entry: WeatherEntry(
                date: Date(),
                location: "Seattle, WA",
                temperature: 72,
                description: "Partly Cloudy",
                icon: "cloud",
                precipitation: 20,
                windSpeed: 5
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
        }
    }
}