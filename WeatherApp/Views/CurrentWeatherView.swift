import SwiftUI

struct CurrentWeatherView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    
    private var isDaytime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 18
    }
    
    private var currentForecast: DailyForecast? {
        viewModel.weatherData.daily.first
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Location and refresh button
            HStack {
                Text(viewModel.weatherData.location)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        viewModel.refreshWeather()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.white)
                        .rotationEffect(Angle(degrees: viewModel.isRefreshing ? 360 : 0))
                        .animation(
                            viewModel.isRefreshing ? 
                                Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                                .default, 
                            value: viewModel.isRefreshing
                        )
                }
            }
            
            // Current temperature and weather icon
            HStack(alignment: .center, spacing: 20) {
                if let forecast = currentForecast {
                    Text("\(Int(forecast.tempHigh))°")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    WeatherIcon(
                        iconName: forecast.icon,
                        condition: forecast.shortForecast,
                        size: 72
                    )
                    .foregroundColor(.white)
                }
            }
            
            // Weather description
            if let forecast = currentForecast {
                Text(forecast.shortForecast)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // High/Low temperatures
                HStack(spacing: 20) {
                    Label {
                        Text("\(Int(forecast.tempHigh))°")
                            .fontWeight(.medium)
                    } icon: {
                        Image(systemName: "arrow.up")
                    }
                    
                    Label {
                        Text("\(Int(forecast.tempLow))°")
                            .fontWeight(.medium)
                    } icon: {
                        Image(systemName: "arrow.down")
                    }
                    
                    Spacer()
                    
                    // Last updated
                    if let metadata = viewModel.weatherData.metadata, let updated = metadata.updated {
                        Text("Updated: \(formatUpdateTime(updated))")
                            .font(.caption)
                    }
                }
                .foregroundColor(.white)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
    
    private func formatUpdateTime(_ timeString: String) -> String {
        // Simple conversion for demo - in a real app would properly parse the timestamp
        return timeString
    }
}

struct CurrentWeatherView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.blue
            
            CurrentWeatherView()
                .environmentObject(WeatherViewModel())
        }
        .previewLayout(.sizeThatFits)
    }
}
