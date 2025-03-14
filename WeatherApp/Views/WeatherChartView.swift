import SwiftUI

/// Chart view for displaying weather temperature data
struct WeatherChartView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var showingInfo = false
    
    // Chart dimensions
    private let chartHeight: CGFloat = 150
    private let barWidth: CGFloat = 8
    private let barSpacing: CGFloat = 10
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("7-Day Temperature Trend")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showingInfo.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.primary)
                }
                .popover(isPresented: $showingInfo) {
                    chartInfoView
                }
            }
            
            // Temperature chart
            ZStack(alignment: .leading) {
                // Background grid lines
                VStack(spacing: chartHeight / 4) {
                    ForEach(0..<5) { _ in
                        Divider().background(Color.gray.opacity(0.3))
                    }
                }
                
                // Temperature bars
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(viewModel.weatherData.daily) { day in
                        temperatureBar(for: day)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(height: chartHeight)
            
            // X-axis labels
            HStack(spacing: barSpacing) {
                ForEach(viewModel.weatherData.daily) { day in
                    Text(day.day)
                        .font(.caption2)
                        .frame(width: barWidth)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    /// Create a temperature bar for a day
    func temperatureBar(for day: DailyForecast) -> some View {
        VStack(spacing: 0) {
            // Temperature value label
            Text(viewModel.getTemperatureString(day.tempHigh))
                .font(.system(size: 8))
                .padding(.bottom, 2)
            
            // Temperature bar
            VStack(spacing: 4) {
                // High temperature
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red.opacity(0.6))
                    .frame(width: barWidth, height: normalizedHeight(day.tempHigh))
                
                // Low temperature
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: barWidth, height: normalizedHeight(day.tempLow))
            }
            
            // Low temperature label
            Text(viewModel.getTemperatureString(day.tempLow))
                .font(.system(size: 8))
                .padding(.top, 2)
        }
    }
    
    /// Chart info popover view
    var chartInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chart Information")
                .font(.headline)
            
            Text("This chart shows the high (red) and low (blue) temperatures for each day in the 7-day forecast.")
                .font(.body)
            
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 20, height: 8)
                Text("High Temperature")
            }
            
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 20, height: 8)
                Text("Low Temperature")
            }
        }
        .padding()
        .frame(width: 250)
    }
    
    /// Normalize temperature to chart height
    func normalizedHeight(_ temperature: Double) -> CGFloat {
        // Get min and max temperatures
        let temperatureValues = viewModel.weatherData.daily.flatMap { [$0.tempHigh, $0.tempLow] }
        let minTemp = temperatureValues.min() ?? 0
        let maxTemp = temperatureValues.max() ?? 30
        
        // Calculate range and add some padding
        let range = (maxTemp - minTemp) * 1.1
        
        // Normalize the temperature to chart height
        let normalized = CGFloat((temperature - minTemp) / range) * chartHeight * 0.8
        
        // Ensure a minimum height
        return max(normalized, 4)
    }
}

struct WeatherChartView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherChartView()
            .environmentObject(WeatherViewModel())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
