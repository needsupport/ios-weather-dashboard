import SwiftUI

struct WeatherCardView: View {
    let forecast: DailyForecast
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var isShowingDetails = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Day name
            Text(forecast.fullDay)
                .font(.headline)
            
            // Weather icon
            Image(systemName: viewModel.getSystemIcon(from: forecast.icon))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 30))
                .padding(.vertical, 5)
            
            // Weather description
            Text(forecast.shortForecast)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Temperature range
            HStack(spacing: 5) {
                // High
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text(viewModel.getTemperatureString(forecast.tempHigh))
                        .fontWeight(.medium)
                }
                
                // Low
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text(viewModel.getTemperatureString(forecast.tempLow))
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
            
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
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(viewModel.selectedDayID == forecast.id ? Color.blue : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.setSelectedDay(forecast.id)
            isShowingDetails.toggle()
        }
        .sheet(isPresented: $isShowingDetails) {
            DayDetailView(forecast: forecast)
        }
    }
}

// MARK: - Day Detail View
struct DayDetailView: View {
    let forecast: DailyForecast
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Main info section
                    VStack(alignment: .leading, spacing: 16) {
                        // Header with day and date
                        HStack {
                            VStack(alignment: .leading) {
                                Text(forecast.fullDay)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text(formattedDate(forecast.date))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Weather icon
                            Image(systemName: viewModel.getSystemIcon(from: forecast.icon))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 50))
                        }
                        
                        // Temperature and conditions
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                // High temperature
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("High:")
                                        .foregroundColor(.secondary)
                                    Text(viewModel.getTemperatureString(forecast.tempHigh))
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                }
                                
                                // Low temperature
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("Low:")
                                        .foregroundColor(.secondary)
                                    Text(viewModel.getTemperatureString(forecast.tempLow))
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            // Condition description
                            Text(forecast.shortForecast)
                                .font(.headline)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 150, alignment: .trailing)
                        }
                        
                        // Detailed forecast
                        Text(forecast.detailedForecast)
                            .font(.body)
                            .padding(.top, 5)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // Weather metrics section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Weather Metrics")
                            .font(.headline)
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
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // Hourly forecast section (if needed)
                    // Add implementation here if required
                }
                .padding()
            }
            .navigationBarTitle("Weather Details", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
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
