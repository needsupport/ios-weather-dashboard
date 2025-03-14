import SwiftUI

struct WeatherCardView: View {
    let forecast: DailyForecast
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var isShowingDetails = false
    
    // Check if this is today's forecast
    private var isToday: Bool {
        Calendar.current.isDateInToday(forecast.date)
    }
    
    // Check if it's daytime
    private var isDaytime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 20
    }
    
    var body: some View {
        WeatherCard(condition: forecast.shortForecast, isDaytime: isDaytime) {
            VStack(spacing: 12) {
                // Day name with "Today" highlight
                WeatherTypography.day(
                    Text(isToday ? "Today" : forecast.day), 
                    isToday: isToday
                )
                
                // Weather icon
                WeatherIcon(
                    iconName: forecast.icon,
                    condition: forecast.shortForecast,
                    size: 30
                )
                .padding(.vertical, 5)
                
                // Weather description
                WeatherTypography.caption(
                    Text(forecast.shortForecast)
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 36)
                
                // Temperature range with visual indicators
                HStack(spacing: 12) {
                    // High temp
                    VStack(alignment: .center, spacing: 2) {
                        Text("High")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.getTemperatureString(forecast.tempHigh))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    // Temperature bar visualization
                    TemperatureBar(
                        lowTemp: forecast.tempLow,
                        highTemp: forecast.tempHigh,
                        minTemp: viewModel.weatherData.daily.map { $0.tempLow }.min() ?? (forecast.tempLow - 5),
                        maxTemp: viewModel.weatherData.daily.map { $0.tempHigh }.max() ?? (forecast.tempHigh + 5)
                    )
                    .frame(height: 4)
                    .padding(.vertical, 8)
                    
                    // Low temp
                    VStack(alignment: .center, spacing: 2) {
                        Text("Low")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.getTemperatureString(forecast.tempLow))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                
                // Precipitation indicator
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("\(Int(forecast.precipitation.chance))%")
                        .font(.caption)
                }
                .opacity(forecast.precipitation.chance > 0 ? 1.0 : 0.3)
                
                // Divider
                Divider()
                    .padding(.horizontal, 10)
                
                // Bottom row with additional info
                HStack {
                    // Wind
                    HStack(spacing: 2) {
                        Image(systemName: "wind")
                            .font(.system(size: 10))
                        Text("\(Int(forecast.wind.speed))")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    // UV Index
                    HStack(spacing: 2) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 10))
                        Text("\(forecast.uvIndex)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(viewModel.selectedDayID == forecast.id ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            hapticFeedback()
            viewModel.setSelectedDay(forecast.id)
            isShowingDetails.toggle()
        }
        .sheet(isPresented: $isShowingDetails) {
            DayDetailView(forecast: forecast)
        }
    }
    
    // Haptic feedback helper
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Day Detail View
struct DayDetailView: View {
    let forecast: DailyForecast
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Check if it's daytime
    private var isDaytime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 20
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                WeatherGradientBackground(
                    condition: forecast.shortForecast,
                    isDaytime: isDaytime
                )
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Main info section
                        WeatherCard(condition: forecast.shortForecast, isDaytime: isDaytime) {
                            VStack(alignment: .leading, spacing: 16) {
                                // Header with day and date
                                HStack {
                                    VStack(alignment: .leading) {
                                        WeatherTypography.title(
                                            Text(forecast.fullDay)
                                        )
                                        
                                        WeatherTypography.subheadline(
                                            Text(formattedDate(forecast.date))
                                        )
                                    }
                                    
                                    Spacer()
                                    
                                    // Weather icon
                                    WeatherIcon(
                                        iconName: forecast.icon,
                                        condition: forecast.shortForecast,
                                        size: 50
                                    )
                                }
                                
                                // Temperature and conditions
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        // High temperature
                                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                                            Text("High:")
                                                .foregroundColor(.secondary)
                                            WeatherTypography.temperature(
                                                Text(viewModel.getTemperatureString(forecast.tempHigh))
                                            )
                                            .foregroundColor(.red)
                                        }
                                        
                                        // Low temperature
                                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                                            Text("Low:")
                                                .foregroundColor(.secondary)
                                            WeatherTypography.temperature(
                                                Text(viewModel.getTemperatureString(forecast.tempLow))
                                            )
                                            .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Condition description
                                    WeatherTypography.condition(
                                        Text(forecast.shortForecast)
                                    )
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 150, alignment: .trailing)
                                }
                                
                                // Detailed forecast
                                Text(forecast.detailedForecast)
                                    .font(.body)
                                    .padding(.top, 5)
                            }
                        }
                        
                        // Weather metrics section
                        WeatherCard(condition: forecast.shortForecast, isDaytime: isDaytime) {
                            VStack(alignment: .leading, spacing: 16) {
                                WeatherTypography.headline(
                                    Text("Weather Metrics")
                                )
                                .padding(.bottom, 4)
                                
                                // Grid of metrics
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    // Precipitation
                                    metricCard(
                                        title: "Precipitation",
                                        value: "\(Int(forecast.precipitation.chance))%",
                                        icon: "drop.fill",
                                        color: .blue
                                    )
                                    
                                    // Humidity
                                    if let humidity = forecast.humidity {
                                        metricCard(
                                            title: "Humidity",
                                            value: "\(Int(humidity))%",
                                            icon: "humidity",
                                            color: .cyan
                                        )
                                    }
                                    
                                    // Wind
                                    metricCard(
                                        title: "Wind",
                                        value: "\(Int(forecast.wind.speed)) mph",
                                        subtitle: forecast.wind.direction,
                                        icon: "wind",
                                        color: .teal
                                    )
                                    
                                    // UV Index
                                    metricCard(
                                        title: "UV Index",
                                        value: "\(forecast.uvIndex)",
                                        subtitle: uvIndexCategory(forecast.uvIndex),
                                        icon: "sun.max.fill",
                                        color: uvIndexColor(forecast.uvIndex)
                                    )
                                    
                                    // Dew Point
                                    if let dewpoint = forecast.dewpoint {
                                        metricCard(
                                            title: "Dew Point",
                                            value: viewModel.getTemperatureString(dewpoint),
                                            icon: "thermometer.medium",
                                            color: .green
                                        )
                                    }
                                    
                                    // Pressure
                                    if let pressure = forecast.pressure {
                                        metricCard(
                                            title: "Pressure",
                                            value: "\(Int(pressure)) hPa",
                                            icon: "gauge",
                                            color: .purple
                                        )
                                    }
                                    
                                    // Sky Cover
                                    if let skyCover = forecast.skyCover {
                                        metricCard(
                                            title: "Cloud Cover",
                                            value: "\(Int(skyCover))%",
                                            icon: "cloud.fill",
                                            color: .gray
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationBarTitle("Weather Details", displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") {
                    dismiss()
                })
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
        }
    }
    
    // MARK: - Helper Views
    private func metricCard(title: String, value: String, subtitle: String? = nil, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Helper Functions
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func uvIndexCategory(_ index: Int) -> String {
        switch index {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
    
    private func uvIndexColor(_ index: Int) -> Color {
        switch index {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
}

// MARK: - Preview
struct WeatherCardView_Previews: PreviewProvider {
    static var previews: some View {
        let mockForecast = DailyForecast(
            id: "day-1",
            day: "Mon",
            fullDay: "Monday",
            date: Date(),
            tempHigh: 25.0,
            tempLow: 15.0,
            precipitation: Precipitation(chance: 30.0),
            uvIndex: 6,
            wind: Wind(speed: 12.0, direction: "NE"),
            icon: "sun",
            detailedForecast: "Mostly sunny with a chance of afternoon showers. Temperatures remain warm with moderate humidity.",
            shortForecast: "Mostly Sunny",
            humidity: 65.0,
            dewpoint: 12.0,
            pressure: 1013.0,
            skyCover: 30.0
        )
        
        WeatherCardView(forecast: mockForecast)
            .environmentObject(WeatherViewModel())
            .frame(width: 160)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
