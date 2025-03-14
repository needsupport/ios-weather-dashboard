import SwiftUI

struct WeatherDashboardView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var selectedTab = 0
    @Environment(\.colorScheme) var colorScheme
    
    var isDaytime: Bool {
        guard !viewModel.weatherData.daily.isEmpty else { return true }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 18
    }
    
    var currentCondition: String {
        viewModel.weatherData.daily.first?.shortForecast ?? "Clear"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current weather with dynamic background
                if let currentForecast = viewModel.weatherData.daily.first {
                    ZStack {
                        // Dynamic background based on weather condition
                        Color.weatherGradient(
                            for: currentForecast.shortForecast,
                            isDaytime: isDaytime
                        )
                        .ignoresSafeArea(edges: .top)
                        
                        // Weather effects
                        if currentForecast.shortForecast.lowercased().contains("rain") {
                            RainEffect(intensity: currentForecast.precipitation.chance / 100)
                                .ignoresSafeArea(edges: .top)
                        }
                        
                        CurrentWeatherView()
                            .padding(.top, 30)
                            .padding(.horizontal)
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                }
                
                // Tab selector with improved visual design
                ImprovedTabSelector(selectedTab: $selectedTab, titles: ["Daily", "Hourly", "Details"])
                
                // Content based on selected tab
                tabContent
                    .padding(.bottom)
            }
            .padding(.vertical)
        }
        .refreshable {
            viewModel.refreshWeather()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading weather data...")
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 5)
                    )
            }
        }
        .onChange(of: viewModel.weatherData) { _ in
            // Apply subtle animations when data updates
            withAnimation(.easeInOut(duration: 0.5)) {
                // Animation trigger
            }
        }
        .alert(item: Binding<AlertItem?>(
            get: {
                if let error = viewModel.error {
                    return AlertItem(
                        id: UUID().uuidString,
                        title: "Error",
                        message: error,
                        dismissButton: .default(Text("OK"))
                    )
                }
                return nil
            },
            set: { _ in
                viewModel.error = nil
            }
        )) { alertItem in
            Alert(
                title: Text(alertItem.title),
                message: Text(alertItem.message),
                dismissButton: alertItem.dismissButton
            )
        }
    }
    
    // Content based on selected tab
    @ViewBuilder
    var tabContent: some View {
        switch selectedTab {
        case 0:
            dailyForecastView
        case 1:
            hourlyForecastView
        case 2:
            detailsView
        default:
            dailyForecastView
        }
    }
    
    // Daily forecast view
    var dailyForecastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-Day Forecast")
                .weatherHeadline()
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.weatherData.daily) { forecast in
                        DailyForecastCard(forecast: forecast, 
                                          isSelected: viewModel.selectedDayID == forecast.id,
                                          isDaytime: isDaytime)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.setSelectedDay(forecast.id)
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
            
            if let selectedForecast = viewModel.weatherData.daily.first(where: { $0.id == viewModel.selectedDayID }) {
                selectedDayDetailView(for: selectedForecast)
            }
        }
    }
    
    // Hourly forecast view
    var hourlyForecastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly Forecast")
                .weatherHeadline()
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.weatherData.hourly) { forecast in
                        HourlyForecastRow(forecast: forecast)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Details view
    var detailsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather Details")
                .weatherHeadline()
                .padding(.horizontal)
            
            if let currentForecast = viewModel.weatherData.daily.first {
                VStack(spacing: 20) {
                    // Detailed info cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        DetailInfoCard(title: "UV Index", value: "\(currentForecast.uvIndex)")
                        DetailInfoCard(title: "Humidity", value: "\(Int(currentForecast.humidity ?? 0))%")
                        DetailInfoCard(title: "Wind", value: "\(Int(currentForecast.wind.speed)) \(currentForecast.wind.direction)")
                        DetailInfoCard(title: "Precipitation", value: "\(Int(currentForecast.precipitation.chance))%")
                    }
                    .padding(.horizontal)
                    
                    // Detailed forecast
                    WeatherCard(condition: currentForecast.shortForecast, isDaytime: isDaytime) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Forecast Details")
                                .font(.headline)
                            
                            Text(currentForecast.detailedForecast)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    
                    // Weather alerts
                    if !viewModel.alerts.isEmpty {
                        alertsView
                    }
                }
            }
        }
    }
    
    // Selected day detail view
    func selectedDayDetailView(for forecast: DailyForecast) -> some View {
        WeatherCard(condition: forecast.shortForecast, isDaytime: isDaytime) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(forecast.fullDay)
                            .font(.headline)
                        
                        Text(forecast.shortForecast)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Label {
                                Text("\(Int(forecast.tempHigh))°")
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        HStack {
                            Label {
                                Text("\(Int(forecast.tempLow))°")
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Additional forecast details
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(icon: "wind", title: "Wind", value: "\(Int(forecast.wind.speed)) mph \(forecast.wind.direction)")
                        DetailRow(icon: "humidity", title: "Humidity", value: "\(Int(forecast.humidity ?? 0))%")
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(icon: "drop.fill", title: "Precipitation", value: "\(Int(forecast.precipitation.chance))%")
                        DetailRow(icon: "sun.max.fill", title: "UV Index", value: getUVIndexText(forecast.uvIndex))
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    // Alerts view
    var alertsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weather Alerts")
                .weatherHeadline()
                .padding(.horizontal)
            
            ForEach(viewModel.alerts) { alert in
                AlertCard(alert: alert)
            }
        }
    }
    
    // Helper function for UV index
    func getUVIndexText(_ index: Int) -> String {
        switch index {
        case 0...2: return "\(index) (Low)"
        case 3...5: return "\(index) (Moderate)"
        case 6...7: return "\(index) (High)"
        case 8...10: return "\(index) (Very High)"
        default: return "\(index) (Extreme)"
        }
    }
}

// Alert item for error handling
struct AlertItem: Identifiable {
    var id: String
    var title: String
    var message: String
    var dismissButton: Alert.Button
}

// Daily forecast card
struct DailyForecastCard: View {
    let forecast: DailyForecast
    let isSelected: Bool
    let isDaytime: Bool
    
    var body: some View {
        WeatherCard(condition: forecast.shortForecast, isDaytime: isDaytime, hasShadow: isSelected) {
            VStack(spacing: 12) {
                // Day label with "Today" highlight
                Text(isToday ? "Today" : forecast.day)
                    .font(.headline)
                    .foregroundColor(isToday ? .accentColor : .primary)
                
                // Weather icon with improved rendering
                WeatherIcon(
                    iconName: forecast.icon,
                    condition: forecast.shortForecast,
                    size: 30
                )
                .padding(.vertical, 5)
                
                // Weather description with better wrapping
                Text(forecast.shortForecast)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
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
                        
                        Text("\(Int(forecast.tempHigh))°")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    // Low temp
                    VStack(alignment: .center, spacing: 2) {
                        Text("Low")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(forecast.tempLow))°")
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
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 120)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    // Check if this is today's forecast
    private var isToday: Bool {
        Calendar.current.isDateInToday(forecast.date)
    }
}

// Hourly forecast row
struct HourlyForecastRow: View {
    let forecast: HourlyForecast
    
    var body: some View {
        HStack(spacing: 16) {
            // Time
            Text(forecast.time)
                .font(.headline)
                .frame(width: 50, alignment: .leading)
            
            // Weather icon
            WeatherIcon(
                iconName: forecast.icon,
                condition: forecast.shortForecast,
                size: 24
            )
            
            // Forecast
            Text(forecast.shortForecast)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Temperature
            Text("\(Int(forecast.temperature))°")
                .font(.headline)
                .frame(width: 50, alignment: .trailing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// Weather alert card
struct AlertCard: View {
    let alert: WeatherAlert
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.alertColor(for: alert.severity))
                    .frame(width: 12, height: 12)
                
                Text(alert.headline)
                    .font(.headline)
                    .foregroundColor(Color.alertColor(for: alert.severity))
                
                Spacer()
                
                if let end = alert.end {
                    Text("Until \(timeFormatter.string(from: end))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(alert.description)
                .font(.body)
                .lineLimit(3)
            
            Button("View Details") {
                // Action to show alert details
            }
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
}

// Detail info card
struct DetailInfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// Detail row for additional information
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
            }
        }
    }
}

// Preview
struct WeatherDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherDashboardView()
            .environmentObject(WeatherViewModel())
    }
}
