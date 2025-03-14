import SwiftUI

struct CurrentWeatherView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Current conditions section
            if let todayForecast = viewModel.weatherData.daily.first {
                currentConditionsView(todayForecast)
            } else {
                Text("No data available")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Today's Details section
            if let todayForecast = viewModel.weatherData.daily.first {
                todayDetailsView(todayForecast)
            }
        }
    }
    
    // MARK: - Current Conditions Section
    private func currentConditionsView(_ forecast: DailyForecast) -> some View {
        VStack(spacing: 8) {
            // Main temperature section
            HStack(alignment: .center, spacing: 20) {
                // Weather icon
                Image(systemName: viewModel.getSystemIcon(from: forecast.icon))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 70))
                    .opacity(isAnimating ? 1.0 : 0.7)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
                
                // Temperature and description
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.getTemperatureString(forecast.tempHigh))
                        .font(.system(size: 50, weight: .medium))
                    
                    Text(forecast.shortForecast)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    // Min/Max
                    HStack {
                        Text("H: \(viewModel.getTemperatureString(forecast.tempHigh))")
                        Text("L: \(viewModel.getTemperatureString(forecast.tempLow))")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)
            
            // Forecast summary
            Text(forecast.detailedForecast)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Today's Details Section
    private func todayDetailsView(_ forecast: DailyForecast) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Details")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Humidity
                weatherDetailCard(
                    title: "Humidity",
                    value: "\(Int(forecast.humidity ?? 0))%",
                    icon: "humidity",
                    color: .blue
                )
                
                // Wind
                weatherDetailCard(
                    title: "Wind",
                    value: "\(Int(forecast.wind.speed)) mph \(forecast.wind.direction)",
                    icon: "wind",
                    color: .cyan
                )
                
                // Precipitation
                weatherDetailCard(
                    title: "Precipitation",
                    value: "\(Int(forecast.precipitation.chance))%",
                    icon: "cloud.rain",
                    color: .indigo
                )
                
                // UV Index
                weatherDetailCard(
                    title: "UV Index",
                    value: uvIndexDescription(for: forecast.uvIndex),
                    icon: "sun.max",
                    color: .orange
                )
                
                // Dew Point
                if let dewpoint = forecast.dewpoint {
                    weatherDetailCard(
                        title: "Dew Point",
                        value: viewModel.getTemperatureString(dewpoint),
                        icon: "thermometer.medium",
                        color: .green
                    )
                }
                
                // Pressure
                if let pressure = forecast.pressure {
                    weatherDetailCard(
                        title: "Pressure",
                        value: "\(Int(pressure)) hPa",
                        icon: "arrow.down.to.line",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Weather Detail Card
    private func weatherDetailCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Functions
    private func uvIndexDescription(for index: Int) -> String {
        switch index {
        case 0...2:
            return "\(index) Low"
        case 3...5:
            return "\(index) Moderate"
        case 6...7:
            return "\(index) High"
        case 8...10:
            return "\(index) Very High"
        default:
            return "\(index) Extreme"
        }
    }
}

// MARK: - Preview
struct CurrentWeatherView_Previews: PreviewProvider {
    static var previews: some View {
        CurrentWeatherView()
            .environmentObject(WeatherViewModel())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
