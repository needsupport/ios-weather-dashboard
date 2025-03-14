import SwiftUI

/// A centralized design system for the Weather App to ensure consistent styling across the application.
/// This component provides colors, typography, spacing, and reusable UI elements.
struct WeatherDesignSystem {
    // MARK: - Colors
    
    struct Colors {
        // Base colors
        static let weatherBlue = Color("WeatherBlue", bundle: nil) ?? Color(red: 0.0, green: 0.5, blue: 0.9)
        static let weatherYellow = Color("WeatherYellow", bundle: nil) ?? Color(red: 0.95, green: 0.8, blue: 0.0)
        static let weatherGray = Color("WeatherGray", bundle: nil) ?? Color(red: 0.6, green: 0.6, blue: 0.6)
        
        // Dynamic condition-based colors
        static func weatherBackground(for condition: String, isDaytime: Bool) -> LinearGradient {
            let colors: [Color]
            
            switch condition.lowercased() {
            case _ where condition.contains("clear"), _ where condition.contains("sunny"):
                colors = isDaytime ? 
                    [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.0, green: 0.5, blue: 0.9)] :
                    [Color(red: 0.1, green: 0.2, blue: 0.5), Color(red: 0.0, green: 0.0, blue: 0.3)]
            case _ where condition.contains("cloud"):
                colors = isDaytime ?
                    [Color(red: 0.6, green: 0.7, blue: 0.9), Color(red: 0.4, green: 0.5, blue: 0.7)] :
                    [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.1, blue: 0.2)]
            case _ where condition.contains("rain"):
                colors = [Color(red: 0.3, green: 0.3, blue: 0.5), Color(red: 0.1, green: 0.1, blue: 0.3)]
            case _ where condition.contains("snow"):
                colors = [Color(red: 0.7, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.5, blue: 0.7)]
            case _ where condition.contains("fog"):
                colors = [Color(red: 0.5, green: 0.5, blue: 0.6), Color(red: 0.3, green: 0.3, blue: 0.4)]
            default:
                colors = isDaytime ?
                    [Color(red: 0.5, green: 0.6, blue: 0.8), Color(red: 0.3, green: 0.4, blue: 0.6)] :
                    [Color(red: 0.2, green: 0.2, blue: 0.4), Color(red: 0.1, green: 0.1, blue: 0.2)]
            }
            
            return LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
        }
        
        // Alert severity colors
        static func alertColor(for severity: String) -> Color {
            switch severity.lowercased() {
            case "extreme": return Color(red: 0.8, green: 0.0, blue: 0.0)
            case "severe": return Color(red: 0.8, green: 0.2, blue: 0.0)
            case "moderate": return Color(red: 0.9, green: 0.5, blue: 0.0)
            default: return Color(red: 0.9, green: 0.8, blue: 0.0)
            }
        }
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Define text styles for consistent typography
        static func largeTitle(_ content: Text) -> some View {
            content
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        
        static func title(_ content: Text) -> some View {
            content
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        
        static func headline(_ content: Text) -> some View {
            content
                .font(.headline)
                .foregroundColor(.primary)
        }
        
        static func subheadline(_ content: Text) -> some View {
            content
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        
        static func body(_ content: Text) -> some View {
            content
                .font(.body)
                .foregroundColor(.primary)
        }
        
        static func caption(_ content: Text) -> some View {
            content
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        static func temperatureDisplay(_ content: Text, isHighlight: Bool = false) -> some View {
            content
                .font(.system(size: isHighlight ? 50 : 24, weight: .medium, design: .rounded))
                .foregroundColor(isHighlight ? .primary : .secondary)
        }
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        // Standard spacing values based on 8-point grid
        static let xsmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
        static let xxlarge: CGFloat = 48
        
        // Content padding
        static let contentPadding: EdgeInsets = EdgeInsets(
            top: medium,
            leading: medium,
            bottom: medium,
            trailing: medium
        )
        
        // Card padding
        static let cardPadding: EdgeInsets = EdgeInsets(
            top: medium,
            leading: medium,
            bottom: medium,
            trailing: medium
        )
    }
    
    // MARK: - Components
    
    struct Components {
        // WeatherCard component for consistent card styling
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
                    .padding(Spacing.cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: hasShadow ? Color.black.opacity(0.1) : .clear, 
                                    radius: 10, x: 0, y: 5)
                    )
            }
        }
        
        // WeatherIcon component for consistent icon styling
        struct WeatherIcon: View {
            let iconName: String
            let condition: String
            let size: CGFloat
            @State private var isAnimating = false
            
            var body: some View {
                Image(systemName: mapToSystemIcon(iconName))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: size))
                    .foregroundStyle(iconForegroundStyle(for: condition))
                    .padding(Spacing.small)
                    .onAppear {
                        // Only animate certain conditions
                        if condition.contains("rain") || condition.contains("snow") || condition.contains("wind") {
                            withAnimation(Animation.easeInOut(duration: 2).repeatForever()) {
                                isAnimating = true
                            }
                        }
                    }
            }
            
            // Map weather icon names to SF Symbols
            private func mapToSystemIcon(_ iconName: String) -> String {
                switch iconName {
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
            
            // Create appropriate foreground style based on weather condition
            private func iconForegroundStyle(for condition: String) -> some ShapeStyle {
                if #available(iOS 16.0, *) {
                    if condition.contains("rain") {
                        return .linearGradient(
                            colors: [.gray, .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else if condition.contains("snow") {
                        return .linearGradient(
                            colors: [.white, .blue.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else if condition.contains("clear") && !condition.contains("night") {
                        return .linearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                
                // Default behavior for older iOS versions or other conditions
                return Color.blue
            }
        }
        
        // ButtonStyle for consistent button styling
        struct WeatherButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .padding(.vertical, Spacing.small)
                    .padding(.horizontal, Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1.0))
                    )
                    .foregroundColor(.white)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
                    .animation(.spring(), value: configuration.isPressed)
            }
        }
        
        // TabStyle for consistent tab styling
        struct WeatherTabStyle: View {
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
    }
    
    // MARK: - Animations
    
    struct Animations {
        // Standard animation curves
        static let defaultAnimation = Animation.easeInOut(duration: 0.3)
        static let springAnimation = Animation.spring(response: 0.5, dampingFraction: 0.7)
        static let tabChangeAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)
        
        // Transition animations
        static let defaultTransition = AnyTransition.opacity.combined(with: .slide)
        static let cardTransition = AnyTransition.scale.combined(with: .opacity)
    }
    
    // MARK: - Accessibility
    
    struct Accessibility {
        // Helper functions for improved accessibility
        static func temperatureLabel(value: Double, unit: String) -> String {
            return "\(Int(round(value))) degrees \(unit == "C" ? "Celsius" : "Fahrenheit")"
        }
        
        static func precipitationLabel(chance: Double) -> String {
            return "\(Int(round(chance))) percent chance of precipitation"
        }
        
        static func windLabel(speed: Double, direction: String) -> String {
            return "Wind \(Int(round(speed))) miles per hour from the \(direction)"
        }
        
        static func alertLabel(severity: String, title: String) -> String {
            return "\(severity) weather alert: \(title)"
        }
    }
}

// MARK: - View Extensions

// Text style extensions for easier use of the design system
extension Text {
    func weatherLargeTitle() -> some View {
        WeatherDesignSystem.Typography.largeTitle(self)
    }
    
    func weatherTitle() -> some View {
        WeatherDesignSystem.Typography.title(self)
    }
    
    func weatherHeadline() -> some View {
        WeatherDesignSystem.Typography.headline(self)
    }
    
    func weatherSubheadline() -> some View {
        WeatherDesignSystem.Typography.subheadline(self)
    }
    
    func weatherBody() -> some View {
        WeatherDesignSystem.Typography.body(self)
    }
    
    func weatherCaption() -> some View {
        WeatherDesignSystem.Typography.caption(self)
    }
    
    func temperatureDisplay(isHighlight: Bool = false) -> some View {
        WeatherDesignSystem.Typography.temperatureDisplay(self, isHighlight: isHighlight)
    }
}
