import SwiftUI

// MARK: - Color System
extension Color {
    // Base colors
    static let weatherBlue = Color("WeatherBlue")
    static let weatherYellow = Color("WeatherYellow")
    static let weatherGray = Color("WeatherGray")
    
    // Dynamic condition-based colors
    static func weatherBackground(for condition: String, isDaytime: Bool) -> Color {
        switch condition.lowercased() {
        case _ where condition.contains("clear"), _ where condition.contains("sunny"):
            return isDaytime ? Color("ClearDayBackground") : Color("ClearNightBackground")
        case _ where condition.contains("cloud"):
            return isDaytime ? Color("CloudyDayBackground") : Color("CloudyNightBackground")
        case _ where condition.contains("rain"):
            return Color("RainyBackground")
        case _ where condition.contains("snow"):
            return Color("SnowyBackground")
        case _ where condition.contains("fog"):
            return Color("FoggyBackground")
        default:
            return isDaytime ? Color("DefaultDayBackground") : Color("DefaultNightBackground")
        }
    }
    
    // Alert severity colors
    static func alertColor(for severity: String) -> Color {
        switch severity.lowercased() {
        case "extreme": return Color("AlertExtreme")
        case "severe": return Color("AlertSevere")
        case "moderate": return Color("AlertModerate")
        default: return Color("AlertMinor")
        }
    }
}

// MARK: - Typography System
struct WeatherTypography {
    // Title styles
    static func title(_ text: Text) -> some View {
        text.font(.system(size: 28, weight: .bold))
            .foregroundColor(.primary)
    }
    
    static func headline(_ text: Text) -> some View {
        text.font(.headline)
            .foregroundColor(.primary)
    }
    
    static func subheadline(_ text: Text) -> some View {
        text.font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    // Temperature display
    static func temperature(_ text: Text, isHighlight: Bool = false) -> some View {
        text.font(.system(size: isHighlight ? 50 : 24, weight: .medium, design: .rounded))
            .foregroundColor(isHighlight ? .primary : .secondary)
    }
    
    // Weather condition text
    static func condition(_ text: Text) -> some View {
        text.font(.system(size: 16, weight: .medium))
            .foregroundColor(.primary)
    }
    
    // Day of week
    static func day(_ text: Text, isToday: Bool = false) -> some View {
        text.font(.system(size: 14, weight: isToday ? .bold : .regular))
            .foregroundColor(isToday ? .accentColor : .primary)
    }
    
    // Caption text
    static func caption(_ text: Text) -> some View {
        text.font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Weather Card Component
struct WeatherCard<Content: View>: View {
    let condition: String
    let isDaytime: Bool
    let content: Content
    var hasShadow: Bool = true
    
    init(condition: String, isDaytime: Bool, hasShadow: Bool = true, @ViewBuilder content: () -> Content) {
        self.condition = condition
        self.isDaytime = isDaytime
        self.content = content()
        self.hasShadow = hasShadow
    }
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: hasShadow ? Color.black.opacity(0.1) : .clear, 
                            radius: 10, x: 0, y: 5)
            )
    }
}

// MARK: - Weather Icon Component
struct WeatherIcon: View {
    let iconName: String
    let condition: String
    let size: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: getSystemIcon(from: iconName))
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size))
            .symbolEffect(.variableColor.reversing, options: .repeat(3).speed(1), value: isAnimating)
            .onAppear {
                // Only animate certain conditions
                if condition.contains("rain") || condition.contains("snow") || condition.contains("wind") {
                    isAnimating = true
                }
            }
    }
    
    // Helper function to get system icon
    private func getSystemIcon(from weatherCode: String) -> String {
        switch weatherCode {
        case "clear-day": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "partly-cloudy-day": return "cloud.sun.fill"
        case "partly-cloudy-night": return "cloud.moon.fill"
        case "cloudy": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "sleet": return "cloud.sleet.fill"
        case "snow": return "cloud.snow.fill"
        case "wind": return "wind"
        case "fog": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Temperature Bar Component
struct TemperatureBar: View {
    let lowTemp: Double
    let highTemp: Double
    let minTemp: Double
    let maxTemp: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background bar
                Capsule()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: geo.size.width, height: 4)
                
                // Temperature range fill
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: calculateBarWidth(in: geo.size.width), height: 4)
                    .offset(x: calculateBarOffset(in: geo.size.width))
            }
        }
        .frame(height: 4)
    }
    
    // Calculate the width of the colored section proportional to the range
    private func calculateBarWidth(in totalWidth: CGFloat) -> CGFloat {
        let totalRange = maxTemp - minTemp
        let currentRange = highTemp - lowTemp
        return (currentRange / totalRange) * totalWidth
    }
    
    // Calculate the offset from the left based on the low temp
    private func calculateBarOffset(in totalWidth: CGFloat) -> CGFloat {
        let totalRange = maxTemp - minTemp
        let lowTempOffset = lowTemp - minTemp
        return (lowTempOffset / totalRange) * totalWidth
    }
}

// MARK: - Tab Selector Component
struct TabSelector: View {
    let titles: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        HStack {
            ForEach(0..<titles.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedIndex = index
                    }
                }) {
                    Text(titles[index])
                        .fontWeight(selectedIndex == index ? .bold : .regular)
                        .foregroundColor(selectedIndex == index ? .primary : .secondary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            selectedIndex == index ?
                            Capsule()
                                .fill(Color.accentColor.opacity(0.2)) :
                            Capsule()
                                .fill(Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Weather Gradient Background
struct WeatherGradientBackground: View {
    let condition: String
    let isDaytime: Bool
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: backgroundColors),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var backgroundColors: [Color] {
        if condition.contains("clear") || condition.contains("sunny") {
            return isDaytime ? 
                [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.0, green: 0.5, blue: 0.9)] :
                [Color(red: 0.1, green: 0.2, blue: 0.5), Color(red: 0.0, green: 0.0, blue: 0.3)]
        } else if condition.contains("cloud") {
            return isDaytime ?
                [Color(red: 0.6, green: 0.7, blue: 0.9), Color(red: 0.4, green: 0.5, blue: 0.7)] :
                [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.1, blue: 0.2)]
        } else if condition.contains("rain") {
            return [Color(red: 0.3, green: 0.3, blue: 0.5), Color(red: 0.1, green: 0.1, blue: 0.3)]
        } else if condition.contains("snow") {
            return [Color(red: 0.7, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.5, blue: 0.7)]
        } else if condition.contains("fog") {
            return [Color(red: 0.6, green: 0.6, blue: 0.6), Color(red: 0.3, green: 0.3, blue: 0.3)]
        } else {
            return isDaytime ?
                [Color(red: 0.5, green: 0.6, blue: 0.8), Color(red: 0.3, green: 0.4, blue: 0.6)] :
                [Color(red: 0.2, green: 0.2, blue: 0.4), Color(red: 0.1, green: 0.1, blue: 0.2)]
        }
    }
}

// MARK: - Weather Alert Badge
struct WeatherAlertBadge: View {
    let severity: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(alertColor.opacity(0.9))
        .clipShape(Capsule())
    }
    
    private var alertColor: Color {
        switch severity.lowercased() {
        case "extreme": return .red
        case "severe": return .orange
        case "moderate": return .yellow
        default: return .blue
        }
    }
}

// MARK: - View Extensions
extension View {
    // Add haptic feedback to views
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
    
    // Apply conditional modifier
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
