# Widget Implementation Guide

## Introduction

This guide explains how to implement and customize the iOS Weather Dashboard widgets, including home screen widgets and lock screen widgets (iOS 16+).

## Widget Types

The iOS Weather Dashboard app provides the following widget types:

1. **Home Screen Widgets**
   - Small: Current temperature and conditions
   - Medium: Current temperature with additional metrics
   - Large: Comprehensive weather display with multiple metrics

2. **Lock Screen Widgets** (iOS 16+)
   - Circular: Temperature and icon
   - Rectangular: Temperature, icon, and location
   - Inline: Temperature and conditions

## Project Structure

Widget files are located in the `WeatherWidgetExtension` directory:

- `WeatherWidget.swift`: Home screen widgets
- `WeatherLockScreenWidget.swift`: Lock screen widgets

## Widget Configuration

### Extension Configuration

To configure the widget extension in Xcode:

1. Select your project in the Project Navigator
2. Go to the "Targets" section
3. Click the "+" button to add a new target
4. Select "Widget Extension" and configure it

### Info.plist Configuration

The widget extension's Info.plist file should include:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

## Implementing Widgets

### Widget Entry Point

Widgets are implemented using SwiftUI and WidgetKit. Each widget needs:

1. A **TimelineProvider** to supply data
2. An **Entry** structure to hold the data
3. A **View** to display the widget
4. A **Widget** configuration

### Data Flow

Widgets receive data through the following process:

1. The TimelineProvider requests data (in our case, weather data)
2. Data is transformed into Entry objects
3. Entries are passed to the widget view for rendering
4. WidgetKit schedules updates based on the timeline policy

## Home Screen Widget Implementation

### Entry Structure

```swift
struct WeatherEntry: TimelineEntry {
    let date: Date
    let location: String
    let temperature: Double
    let description: String
    let icon: String
    let precipitation: Double
    let windSpeed: Double
}
```

### TimelineProvider

The TimelineProvider fetches data and creates a timeline of entries:

```swift
struct WeatherWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        // Return placeholder data
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        // Return quick snapshot data
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        // Fetch real data and create a timeline
    }
}
```

### Widget Views

Widgets define different views based on family size:

```swift
struct WeatherWidgetEntryView: View {
    var entry: WeatherWidgetProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall: smallWidget
        case .systemMedium: mediumWidget
        case .systemLarge: largeWidget
        default: smallWidget
        }
    }
    
    // View implementations...
}
```

### Widget Configuration

```swift
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
```

## Lock Screen Widget Implementation

Lock screen widgets are available in iOS 16+ and use the same data model but with different widget families:

```swift
@available(iOSApplicationExtension 16.0, *)
struct WeatherLockScreenWidget: Widget {
    private let kind = "WeatherLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenWidgetProvider()) { entry in
            switch family {
            case .accessoryCircular: LockScreenCircularView(entry: entry)
            case .accessoryRectangular: LockScreenRectangularView(entry: entry)
            case .accessoryInline: LockScreenInlineView(entry: entry)
            @unknown default: LockScreenCircularView(entry: entry)
            }
        }
        .configurationDisplayName("Weather")
        .description("Shows current temperature and conditions.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
```

## Sharing Data with the Main App

To share data between the main app and widgets:

1. Create a **WidgetCenter** to reload widgets when data changes

```swift
import WidgetKit

// In your app when data changes
WidgetCenter.shared.reloadAllTimelines()
```

2. Use **App Groups** to share data:

```swift
// In your widget provider
func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
    let userDefaults = UserDefaults(suiteName: "group.com.yourcompany.weatherapp")
    
    if let data = userDefaults?.data(forKey: "weatherData"),
       let weatherData = try? JSONDecoder().decode(WeatherData.self, from: data) {
        // Create entry from shared data
    }
}
```

## Advanced Widget Features

### Widget Configuration

For user-configurable widgets:

```swift
struct WeatherWidgetConfigurationIntent: 
```