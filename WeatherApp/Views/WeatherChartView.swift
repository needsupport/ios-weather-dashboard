import SwiftUI

struct WeatherChartView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var selectedDataPoint: Int? = nil
    @Environment(\.colorScheme) var colorScheme
    
    // Constants for chart dimensions
    private let chartHeight: CGFloat = 140
    private let chartPadding: CGFloat = 20
    private let pointDiameter: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chart title with accessibility support
            Text("7-Day Temperature Forecast")
                .weatherHeadline()
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            
            // Chart area
            ZStack {
                // Chart background with dynamic coloring
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                            radius: 5, x: 0, y: 2)
                
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Temperature chart showing 7-day forecast")
                    .accessibilityHint("Displays high and low temperatures for the week")
                } else {
                    Text("No forecast data available")
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: chartHeight + 50) // Height for chart + day labels
        }
    }
    
    // Enhanced temperature chart with improved visualization
    private var temperatureChart: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines for better readability
                VStack(spacing: geometry.size.height / 4) {
                    ForEach(0..<5) { i in
                        Divider()
                            .background(Color.gray.opacity(0.2))
                    }
                }
                
                // Historical average range with better styling
                if viewModel.preferences.showHistoricalRange {
                    historicalRangeArea(in: geometry)
                        .accessibilityHidden(true)
                }
                
                // Historical average line with enhanced styling
                if viewModel.preferences.showHistoricalAvg {
                    historicalAverageLine(in: geometry)
                        .accessibilityHidden(true)
                }
                
                // Temperature lines with enhanced styling
                temperatureLines(in: geometry)
                    .accessibilityHidden(true)
                
                // Temperature points with better visual design
                temperaturePoints(in: geometry)
                    .accessibilityHidden(true)
                
                // Temperature anomalies with improved styling
                if viewModel.preferences.showAnomalies {
                    temperatureAnomalies(in: geometry)
                        .accessibilityHidden(true)
                }
                
                // Day grid lines
                dayGridLines(in: geometry)
                    .accessibilityHidden(true)
                
                // Selected day indicator with animation
                if let selectedDay = viewModel.selectedDayID,
                   let index = viewModel.weatherData.daily.firstIndex(where: { $0.id == selectedDay }) {
                    selectedDayIndicator(at: index, in: geometry)
                        .accessibilityHidden(true)
                }
                
                // Gesture overlay for selecting points
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let width = geometry.size.width
                                let dailyCount = viewModel.weatherData.daily.count
                                let segmentWidth = width / CGFloat(dailyCount - 1)
                                
                                let index = Int((value.location.x / segmentWidth).rounded())
                                if index >= 0 && index < dailyCount {
                                    hapticFeedback(style: .light)
                                    selectedDataPoint = index
                                    viewModel.setSelectedDay(viewModel.weatherData.daily[index].id)
                                }
                            }
                            .onEnded { _ in
                                selectedDataPoint = nil
                            }
                    )
            }
        }
    }
    
    // Haptic feedback helper
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // Enhanced styling for temperature lines
    private func temperatureLines(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        let dailyData = viewModel.weatherData.daily
        let count = dailyData.count
        
        // Find min/max temps across all days for scaling
        let allTemps = dailyData.flatMap { [$0.tempHigh, $0.tempLow] }
        let maxTemp = allTemps.max() ?? 100
        let minTemp = allTemps.min() ?? 0
        let tempRange = maxTemp - minTemp
        
        // Function to convert temp to y position
        func tempToY(_ temp: Double) -> CGFloat {
            let normalizedTemp = (temp - minTemp) / tempRange
            return height - (normalizedTemp * height)
        }
        
        return ZStack {
            // High temperature line
            Path { path in
                if count > 0 {
                    let segmentWidth = width / CGFloat(count - 1)
                    path.move(to: CGPoint(x: 0, y: tempToY(dailyData[0].tempHigh)))
                    
                    for i in 1..<count {
                        path.addLine(to: CGPoint(x: CGFloat(i) * segmentWidth, y: tempToY(dailyData[i].tempHigh)))
                    }
                }
            }
            .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            
            // Low temperature line
            Path { path in
                if count > 0 {
                    let segmentWidth = width / CGFloat(count - 1)
                    path.move(to: CGPoint(x: 0, y: tempToY(dailyData[0].tempLow)))
                    
                    for i in 1..<count {
                        path.addLine(to: CGPoint(x: CGFloat(i) * segmentWidth, y: tempToY(dailyData[i].tempLow)))
                    }
                }
            }
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
    
    // Temperature points visualization
    private func temperaturePoints(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        let dailyData = viewModel.weatherData.daily
        let count = dailyData.count
        
        // Find min/max temps for scaling
        let allTemps = dailyData.flatMap { [$0.tempHigh, $0.tempLow] }
        let maxTemp = allTemps.max() ?? 100
        let minTemp = allTemps.min() ?? 0
        let tempRange = maxTemp - minTemp
        
        // Function to convert temp to y position
        func tempToY(_ temp: Double) -> CGFloat {
            let normalizedTemp = (temp - minTemp) / tempRange
            return height - (normalizedTemp * height)
        }
        
        return ZStack {
            // High temperature points
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(Color.red)
                    .frame(width: pointDiameter, height: pointDiameter)
                    .position(
                        x: CGFloat(i) * (width / CGFloat(count - 1)),
                        y: tempToY(dailyData[i].tempHigh)
                    )
            }
            
            // Low temperature points
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(Color.blue)
                    .frame(width: pointDiameter, height: pointDiameter)
                    .position(
                        x: CGFloat(i) * (width / CGFloat(count - 1)),
                        y: tempToY(dailyData[i].tempLow)
                    )
            }
        }
    }
    
    // Historical range area
    private func historicalRangeArea(in geometry: GeometryProxy) -> some View {
        // In a real app, this would use actual historical data
        // For demo purposes, using a static range
        let width = geometry.size.width
        let height = geometry.size.height
        
        return Path { path in
            path.move(to: CGPoint(x: 0, y: height * 0.3))
            path.addLine(to: CGPoint(x: width, y: height * 0.3))
            path.addLine(to: CGPoint(x: width, y: height * 0.7))
            path.addLine(to: CGPoint(x: 0, y: height * 0.7))
            path.closeSubpath()
        }
        .fill(Color.gray.opacity(0.1))
    }
    
    // Historical average line
    private func historicalAverageLine(in geometry: GeometryProxy) -> some View {
        // In a real app, this would use actual historical data
        // For demo purposes, using a static line
        let width = geometry.size.width
        let height = geometry.size.height
        
        return Path { path in
            path.move(to: CGPoint(x: 0, y: height * 0.5))
            path.addLine(to: CGPoint(x: width, y: height * 0.5))
        }
        .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [5]))
    }
    
    // Temperature anomalies
    private func temperatureAnomalies(in geometry: GeometryProxy) -> some View {
        // In a real app, this would compare current temps with historical averages
        // For demo purposes, adding simple indicators
        let width = geometry.size.width
        let height = geometry.size.height
        
        let dailyData = viewModel.weatherData.daily
        let count = dailyData.count
        
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                if i % 2 == 0 { // Simulating anomalies for demo
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                        
                        Text("+2°")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .position(
                        x: CGFloat(i) * (width / CGFloat(count - 1)),
                        y: height * 0.2
                    )
                }
            }
        }
    }
    
    // Day grid lines
    private func dayGridLines(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        let count = viewModel.weatherData.daily.count
        
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                Path { path in
                    let x = CGFloat(i) * (width / CGFloat(count - 1))
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            }
        }
    }
    
    // Selected day indicator
    private func selectedDayIndicator(at index: Int, in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        let x = CGFloat(index) * (width / CGFloat(viewModel.weatherData.daily.count - 1))
        
        return Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))
        }
        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: []))
    }
    
    // Day labels
    private var dayLabels: some View {
        HStack {
            ForEach(viewModel.weatherData.daily) { forecast in
                Text(forecast.day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
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
