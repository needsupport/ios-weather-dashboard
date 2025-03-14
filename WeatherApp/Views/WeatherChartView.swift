import SwiftUI

struct WeatherChartView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var selectedDataPoint: Int? = nil
    
    // Constants for chart dimensions
    private let chartHeight: CGFloat = 140
    private let chartPadding: CGFloat = 20
    private let pointDiameter: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chart title
            Text("7-Day Temperature Forecast")
                .font(.headline)
                .padding(.top, 4)
            
            // Chart area
            ZStack {
                // Chart background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Chart content
                if !viewModel.weatherData.daily.isEmpty {
                    VStack {
                        // Temperature chart
                        temperatureChart
                            .padding(.horizontal, chartPadding)
                            .padding(.vertical, chartPadding)
                        
                        // Day labels
                        dayLabels
                            .padding(.horizontal, chartPadding)
                            .padding(.bottom, 8)
                    }
                } else {
                    Text("No forecast data available")
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: chartHeight + 50) // Height for chart + day labels
        }
    }
    
    // MARK: - Temperature Chart
    private var temperatureChart: some View {
        GeometryReader { geometry in
            ZStack {
                // Historical average range (if enabled)
                if viewModel.preferences.showHistoricalRange {
                    historicalRangeArea(in: geometry)
                }
                
                // Historical average line (if enabled)
                if viewModel.preferences.showHistoricalAvg {
                    historicalAverageLine(in: geometry)
                }
                
                // Temperature lines
                temperatureLines(in: geometry)
                
                // Temperature points
                temperaturePoints(in: geometry)
                
                // Temperature anomalies (if enabled)
                if viewModel.preferences.showAnomalies {
                    temperatureAnomalies(in: geometry)
                }
                
                // Day grid lines
                dayGridLines(in: geometry)
                
                // Selected day indicator
                if let selectedDay = viewModel.selectedDayID,
                   let index = viewModel.weatherData.daily.firstIndex(where: { $0.id == selectedDay }) {
                    selectedDayIndicator(at: index, in: geometry)
                }
            }
        }
    }
    
    // MARK: - Temperature Lines
    private func temperatureLines(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let dailyData = viewModel.weatherData.daily
        
        return Path { path in
            guard !dailyData.isEmpty else { return }
            
            let maxTemp = dailyData.map { $0.tempHigh }.max() ?? 0
            let minTemp = dailyData.map { $0.tempLow }.min() ?? 0
            let range = max(maxTemp - minTemp, 10) // Ensure at least 10 degrees range
            
            // Draw high temperature line
            for i in 0..<dailyData.count {
                let x = width * CGFloat(i) / CGFloat(dailyData.count - 1)
                let normalizedTemp = (dailyData[i].tempHigh - minTemp) / range
                let y = height * (1 - CGFloat(normalizedTemp))
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        
        // Draw low temperature line
        .overlay(
            Path { path in
                guard !dailyData.isEmpty else { return }
                
                let maxTemp = dailyData.map { $0.tempHigh }.max() ?? 0
                let minTemp = dailyData.map { $0.tempLow }.min() ?? 0
                let range = max(maxTemp - minTemp, 10) // Ensure at least 10 degrees range
                
                for i in 0..<dailyData.count {
                    let x = width * CGFloat(i) / CGFloat(dailyData.count - 1)
                    let normalizedTemp = (dailyData[i].tempLow - minTemp) / range
                    let y = height * (1 - CGFloat(normalizedTemp))
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        )
    }
    
    // MARK: - Temperature Points
    private func temperaturePoints(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let dailyData = viewModel.weatherData.daily
        
        return ZStack {
            ForEach(0..<dailyData.count, id: \.self) { i in
                Group {
                    // High temperature point
                    Circle()
                        .fill(Color.red)
                        .frame(width: pointDiameter, height: pointDiameter)
                        .position(
                            x: width * CGFloat(i) / CGFloat(dailyData.count - 1),
                            y: height * (1 - CGFloat((dailyData[i].tempHigh - (dailyData.map { $0.tempLow }.min() ?? 0)) / max((dailyData.map { $0.tempHigh }.max() ?? 0) - (dailyData.map { $0.tempLow }.min() ?? 0), 10)))
                        )
                        .overlay(
                            Text(viewModel.getTemperatureString(dailyData[i].tempHigh))
                                .font(.caption2)
                                .offset(y: -15)
                        )
                    
                    // Low temperature point
                    Circle()
                        .fill(Color.blue)
                        .frame(width: pointDiameter, height: pointDiameter)
                        .position(
                            x: width * CGFloat(i) / CGFloat(dailyData.count - 1),
                            y: height * (1 - CGFloat((dailyData[i].tempLow - (dailyData.map { $0.tempLow }.min() ?? 0)) / max((dailyData.map { $0.tempHigh }.max() ?? 0) - (dailyData.map { $0.tempLow }.min() ?? 0), 10)))
                        )
                        .overlay(
                            Text(viewModel.getTemperatureString(dailyData[i].tempLow))
                                .font(.caption2)
                                .offset(y: 15)
                        )
                }
            }
        }
    }
    
    // MARK: - Historical Range Area
    private func historicalRangeArea(in geometry: GeometryProxy) -> some View {
        Path { path in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Mock historical data - would come from API in real app
            let historicalHighs = [26.0, 25.0, 27.0, 28.0, 26.0, 25.0, 24.0]
            let historicalLows = [16.0, 15.0, 17.0, 18.0, 17.0, 16.0, 15.0]
            
            // Draw top line (historical highs)
            for i in 0..<min(historicalHighs.count, viewModel.weatherData.daily.count) {
                let x = width * CGFloat(i) / CGFloat(viewModel.weatherData.daily.count - 1)
                let dailyData = viewModel.weatherData.daily
                let maxTemp = dailyData.map { $0.tempHigh }.max() ?? 0
                let minTemp = dailyData.map { $0.tempLow }.min() ?? 0
                let range = max(maxTemp - minTemp, 10)
                
                let normalizedTemp = (historicalHighs[i] - minTemp) / range
                let y = height * (1 - CGFloat(normalizedTemp))
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // Draw line to bottom right
            let lastX = width
            let lastY = height * (1 - CGFloat((historicalLows.last! - (viewModel.weatherData.daily.map { $0.tempLow }.min() ?? 0)) / max((viewModel.weatherData.daily.map { $0.tempHigh }.max() ?? 0) - (viewModel.weatherData.daily.map { $0.tempLow }.min() ?? 0), 10)))
            path.addLine(to: CGPoint(x: lastX, y: lastY))
            
            // Draw bottom line (historical lows) in reverse
            for i in (0..<min(historicalLows.count, viewModel.weatherData.daily.count)).reversed() {
                let x = width * CGFloat(i) / CGFloat(viewModel.weatherData.daily.count - 1)
                let dailyData = viewModel.weatherData.daily
                let maxTemp = dailyData.map { $0.tempHigh }.max() ?? 0
                let minTemp = dailyData.map { $0.tempLow }.min() ?? 0
                let range = max(maxTemp - minTemp, 10)
                
                let normalizedTemp = (historicalLows[i] - minTemp) / range
                let y = height * (1 - CGFloat(normalizedTemp))
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Close the path
            path.closeSubpath()
        }
        .fill(Color.gray.opacity(0.2))
    }
    
    // MARK: - Historical Average Line
    private func historicalAverageLine(in geometry: GeometryProxy) -> some View {
        Path { path in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Mock historical average data - would come from API in real app
            let historicalAvgs = [20.0, 21.0, 22.0, 21.0, 20.0, 19.0, 18.0]
            
            for i in 0..<min(historicalAvgs.count, viewModel.weatherData.daily.count) {
                let x = width * CGFloat(i) / CGFloat(viewModel.weatherData.daily.count - 1)
                let dailyData = viewModel.weatherData.daily
                let maxTemp = dailyData.map { $0.tempHigh }.max() ?? 0
                let minTemp = dailyData.map { $0.tempLow }.min() ?? 0
                let range = max(maxTemp - minTemp, 10)
                
                let normalizedTemp = (historicalAvgs[i] - minTemp) / range
                let y = height * (1 - CGFloat(normalizedTemp))
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }
    
    // MARK: - Temperature Anomalies
    private func temperatureAnomalies(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let dailyData = viewModel.weatherData.daily
        
        // Mock historical average data - would come from API in real app
        let historicalAvgs = [20.0, 21.0, 22.0, 21.0, 20.0, 19.0, 18.0]
        
        return ZStack {
            ForEach(0..<min(historicalAvgs.count, dailyData.count), id: \.self) { i in
                let maxTemp = dailyData.map { $0.tempHigh }.max() ?? 0
                let minTemp = dailyData.map { $0.tempLow }.min() ?? 0
                let range = max(maxTemp - minTemp, 10)
                
                let normalizedAvg = (historicalAvgs[i] - minTemp) / range
                let avgY = height * (1 - CGFloat(normalizedAvg))
                
                let normalizedHigh = (dailyData[i].tempHigh - minTemp) / range
                let highY = height * (1 - CGFloat(normalizedHigh))
                
                let x = width * CGFloat(i) / CGFloat(dailyData.count - 1)
                
                // Draw anomaly indicator if current high is significantly different from historical average
                if abs(dailyData[i].tempHigh - historicalAvgs[i]) > 5 {
                    Path { path in
                        path.move(to: CGPoint(x: x, y: avgY))
                        path.addLine(to: CGPoint(x: x, y: highY))
                    }
                    .stroke(dailyData[i].tempHigh > historicalAvgs[i] ? Color.red.opacity(0.7) : Color.blue.opacity(0.7), lineWidth: 2)
                    
                    // Add arrow at the end
                    Image(systemName: dailyData[i].tempHigh > historicalAvgs[i] ? "arrow.up" : "arrow.down")
                        .foregroundColor(dailyData[i].tempHigh > historicalAvgs[i] ? .red : .blue)
                        .font(.system(size: 10))
                        .position(x: x, y: highY - (dailyData[i].tempHigh > historicalAvgs[i] ? 10 : -10))
                }
            }
        }
    }
    
    // MARK: - Day Grid Lines
    private func dayGridLines(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let dailyData = viewModel.weatherData.daily
        
        return ZStack {
            ForEach(0..<dailyData.count, id: \.self) { i in
                let x = width * CGFloat(i) / CGFloat(dailyData.count - 1)
                
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }
        }
    }
    
    // MARK: - Selected Day Indicator
    private func selectedDayIndicator(at index: Int, in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let x = width * CGFloat(index) / CGFloat(viewModel.weatherData.daily.count - 1)
        
        return Rectangle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 2, height: height)
            .position(x: x, y: height / 2)
    }
    
    // MARK: - Day Labels
    private var dayLabels: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.weatherData.daily) { day in
                Text(day.day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .fontWeight(viewModel.selectedDayID == day.id ? .bold : .regular)
            }
        }
    }
}

struct WeatherChartView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherChartView()
            .environmentObject(WeatherViewModel())
            .frame(height: 200)
            .padding()
    }
}
