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
    
    // Get background gradient
    static func weatherGradient(for condition: String, isDaytime: Bool) -> LinearGradient {
        let colors: [Color]
        
        if condition.contains("clear") || condition.contains("sunny") {
            colors = isDaytime ? 
                [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.0, green: 0.5, blue: 0.9)] :
                [Color(red: 0.1, green: 0.2, blue: 0.5), Color(red: 0.0, green: 0.0, blue: 0.3)]
        } else if condition.contains("cloud") {
            colors = isDaytime ?
                [Color(red: 0.6, green: 0.7, blue: 0.9), Color(red: 0.4, green: 0.5, blue: 0.7)] :
                [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.1, blue: 0.2)]
        } else if condition.contains("rain") {
            colors = [Color(red: 0.3, green: 0.3, blue: 0.5), Color(red: 0.1, green: 0.1, blue: 0.3)]
        } else if condition.contains("snow") {
            colors = [Color(red: 0.7, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.5, blue: 0.7)]
        } else {
            colors = isDaytime ?
                [Color(red: 0.5, green: 0.6, blue: 0.8), Color(red: 0.3, green: 0.4, blue: 0.6)] :
                [Color(red: 0.2, green: 0.2, blue: 0.4), Color(red: 0.1, green: 0.1, blue: 0.2)]
        }
        
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Card Design System
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

// MARK: - Typography System
extension Text {
    func weatherHeadline() -> some View {
        self.font(.headline)
            .foregroundColor(.primary)
    }
    
    func weatherTitle() -> some View {
        self.font(.title)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
    }
    
    func weatherSubheadline() -> some View {
        self.font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    func temperatureDisplay(isHighlight: Bool = false) -> some View {
        self.font(.system(size: isHighlight ? 50 : 24, weight: .medium, design: .rounded))
            .foregroundColor(isHighlight ? .primary : .secondary)
    }
}

// MARK: - Weather Icon System
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

// MARK: - Weather Effects
struct RainEffect: View {
    @State private var isAnimating = false
    let intensity: Double // 0.0 to 1.0
    
    var body: some View {
        ZStack {
            ForEach(0..<Int(20 * intensity), id: \.self) { index in
                RainDrop(delay: Double.random(in: 0...2))
            }
        }
        .mask(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black, .black, .black]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct RainDrop: View {
    let delay: Double
    @State private var offset: CGFloat = -50
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 2, height: 10)
            .offset(
                x: CGFloat.random(in: -150...150),
                y: offset
            )
            .onAppear {
                withAnimation(
                    Animation
                        .linear(duration: Double.random(in: 0.8...1.5))
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                ) {
                    offset = 700
                }
            }
    }
}

// MARK: - Improved Tab Selector
struct ImprovedTabSelector: View {
    @Binding var selectedTab: Int
    let titles: [String]
    
    var body: some View {
        HStack {
            ForEach(0..<titles.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    Text(titles[index])
                        .fontWeight(selectedTab == index ? .bold : .regular)
                        .foregroundColor(selectedTab == index ? .primary : .secondary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            selectedTab == index ?
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
