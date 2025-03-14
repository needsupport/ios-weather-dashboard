import SwiftUI

/// Card view for displaying daily forecast information
struct WeatherCardView: View {
    let forecast: DailyForecast
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Day header
            HStack {
                Text(forecast.day)
                    .font(.headline)
                
                Spacer()
                
                Text(formattedDate(forecast.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Weather icon
            weatherIcon
                .font(.system(size: 40))
                .symbolRenderingMode(.multicolor)
                .padding(.vertical, 8)
            
            // Short forecast
            Text(forecast.shortForecast)
                .font(.subheadline)
                .lineLimit(1)
                .multilineTextAlignment(.center)
            
            // Temperature range
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                    Text(viewModel.getTemperatureString(forecast.tempHigh))
                        .font(.headline)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                    Text(viewModel.getTemperatureString(forecast.tempLow))
                        .font(.headline)
                }
            }
            
            // Detail button
            Button(action: {
                showDetails.toggle()
            }) {
                HStack {
                    Text("Details")
                        .font(.footnote)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showDetails) {
                WeatherDetailView(forecast: forecast)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // Get weather icon based on icon string
    @ViewBuilder
    var weatherIcon: some View {
        switch forecast.icon {
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
    
    // Format date to display
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

/// Detailed view for a specific forecast day
struct WeatherDetailView: View {
    let forecast: DailyForecast
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with icon and temperatures
                    HStack(spacing: 20) {
                        weatherIcon
                            .font(.system(size: 80))
                            .symbolRenderingMode(.multicolor)
                        
                        VStack(alignment: .leading) {
                            Text(forecast.fullDay)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(forecast.shortForecast)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("High: \(viewModel.getTemperatureString(forecast.tempHigh))")
                                Text("Low: \(viewModel.getTemperatureString(forecast.tempLow))")
                            }
                            .font(.subheadline)
                            .padding(.top, 2)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    
                    // Detailed forecast
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)
                        
                        Text(forecast.detailedForecast)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    
                    // Additional data grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Wind
                        dataCard(title: "Wind", value: "\(Int(forecast.wind.speed)) mph", icon: "wind")
                        
                        // Precipitation
                        dataCard(title: "Precipitation", value: "\(Int(forecast.precipitation.chance))%", icon: "drop.fill")
                        
                        // UV Index
                        dataCard(title: "UV Index", value: "\(forecast.uvIndex)", icon: "sun.max.fill")
                        
                        // Humidity
                        dataCard(title: "Humidity", value: forecast.humidity != nil ? "\(Int(forecast.humidity!))%" : "N/A", icon: "humidity.fill")
                        
                        // Pressure
                        dataCard(title: "Pressure", value: forecast.pressure != nil ? "\(Int(forecast.pressure!)) hPa" : "N/A", icon: "gauge")
                        
                        // Cloud Cover
                        dataCard(title: "Cloud Cover", value: forecast.skyCover != nil ? "\(Int(forecast.skyCover!))%" : "N/A", icon: "cloud.fill")
                    }
                }
                .padding()
            }
            .navigationBarTitle("Forecast Details", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    // Small data card for details
    func dataCard(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // Get weather icon based on icon string
    @ViewBuilder
    var weatherIcon: some View {
        switch forecast.icon {
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
}

struct WeatherCardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleForecast = DailyForecast(
            id: "day-1",
            day: "Mon",
            fullDay: "Monday",
            date: Date(),
            tempHigh: 28,
            tempLow: 12,
            precipitation: Precipitation(chance: 30),
            uvIndex: 6,
            wind: Wind(speed: 12, direction: "NE"),
            icon: "sun",
            detailedForecast: "A sunny day with light winds from the northeast. Perfect weather for outdoor activities.",
            shortForecast: "Sunny",
            humidity: 65,
            dewpoint: 10,
            pressure: 1012,
            skyCover: 20
        )
        
        WeatherCardView(forecast: sampleForecast)
            .environmentObject(WeatherViewModel())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
