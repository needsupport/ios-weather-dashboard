import SwiftUI

/// View for displaying current weather conditions
struct CurrentWeatherView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Current conditions section
            HStack(alignment: .center, spacing: 24) {
                // Weather icon
                if let forecast = viewModel.weatherData.daily.first {
                    weatherIcon(for: forecast.icon)
                        .font(.system(size: 70))
                        .symbolRenderingMode(.multicolor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Current temperature (using high temp from today)
                    if let today = viewModel.weatherData.daily.first {
                        Text(viewModel.getTemperatureString(today.tempHigh))
                            .font(.system(size: 48, weight: .medium))
                    }
                    
                    // Conditions description
                    if let today = viewModel.weatherData.daily.first {
                        Text(today.shortForecast)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // High/Low temperature
                    if let today = viewModel.weatherData.daily.first {
                        HStack {
                            Label(
                                viewModel.getTemperatureString(today.tempHigh),
                                systemImage: "arrow.up"
                            )
                            
                            Label(
                                viewModel.getTemperatureString(today.tempLow),
                                systemImage: "arrow.down"
                            )
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            
            // Weather details grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let today = viewModel.weatherData.daily.first {
                    // Precipitation
                    weatherDataItem(
                        icon: "drop.fill",
                        title: "Precipitation",
                        value: "\(Int(today.precipitation.chance))%"
                    )
                    
                    // Wind
                    weatherDataItem(
                        icon: "wind",
                        title: "Wind",
                        value: "\(Int(today.wind.speed)) mph \(today.wind.direction)"
                    )
                    
                    // UV Index
                    weatherDataItem(
                        icon: "sun.max.fill",
                        title: "UV Index",
                        value: uvIndexDescription(today.uvIndex)
                    )
                    
                    // Humidity
                    if let humidity = today.humidity {
                        weatherDataItem(
                            icon: "humidity",
                            title: "Humidity",
                            value: "\(Int(humidity))%"
                        )
                    }
                }
            }
            
            // Weather alerts section (if any)
            if !viewModel.alerts.isEmpty {
                alertsPreview
            }
            
            // Last updated info
            if let metadata = viewModel.weatherData.metadata {
                Text("Last updated: \(metadata.updated)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    /// Weather alert preview section
    var alertsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.alerts.prefix(2)) { alert in
                HStack(spacing: 12) {
                    alertIcon(for: alert.severity)
                        .font(.title3)
                    
                    VStack(alignment: .leading) {
                        Text(alert.event)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(alert.headline)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(alertBackground(for: alert.severity))
                )
            }
            
            if viewModel.alerts.count > 2 {
                Text("+ \(viewModel.alerts.count - 2) more alerts")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 4)
            }
        }
    }
    
    /// Weather data item component
    func weatherDataItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 24, height: 24)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    /// Get weather icon based on icon string
    @ViewBuilder
    func weatherIcon(for icon: String) -> some View {
        switch icon {
        case "sun":
            Image(systemName: "sun.max.fill")
        case "cloud":
            Image(systemName: "cloud.fill")
        case "rain":
            Image(systemName: "cloud.rain.fill")
        case "snow":
            Image(systemName: "snow")
        default:
            Image(systemName: "cloud.fill")
        }
    }
    
    /// Get alert icon based on severity
    @ViewBuilder
    func alertIcon(for severity: String) -> some View {
        switch severity.lowercased() {
        case "extreme":
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        case "severe":
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        case "moderate":
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.yellow)
        default:
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
        }
    }
    
    /// Get alert background color based on severity
    func alertBackground(for severity: String) -> Color {
        switch severity.lowercased() {
        case "extreme":
            return Color.red.opacity(0.1)
        case "severe":
            return Color.orange.opacity(0.1)
        case "moderate":
            return Color.yellow.opacity(0.1)
        default:
            return Color.blue.opacity(0.1)
        }
    }
    
    /// Get UV index description text
    func uvIndexDescription(_ index: Int) -> String {
        switch index {
        case 0...2:
            return "\(index) (Low)"
        case 3...5:
            return "\(index) (Moderate)"
        case 6...7:
            return "\(index) (High)"
        case 8...10:
            return "\(index) (Very High)"
        default:
            return "\(index) (Extreme)"
        }
    }
}

struct CurrentWeatherView_Previews: PreviewProvider {
    static var previews: some View {
        CurrentWeatherView()
            .environmentObject(WeatherViewModel())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
