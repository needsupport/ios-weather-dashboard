import SwiftUI
import ActivityKit
import WidgetKit

@available(iOS 16.1, *)
struct WeatherAlertLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WeatherAlertAttributes.self) { context in
            // Dynamic Island Presentation
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(severityColor(context.attributes.severity))
                        Text(context.state.eventType)
                            .bold()
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack {
                        Text(formatTime(context.state.endTime))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.trailing, 8)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.location)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.headline)
                        .lineLimit(2)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            } compactLeading: {
                // Compact Leading
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(severityColor(context.attributes.severity))
                    .font(.system(size: 14))
            } compactTrailing: {
                // Compact Trailing
                Text(context.state.eventType.prefix(4))
                    .bold()
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            } minimal: {
                // Minimal
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(severityColor(context.attributes.severity))
                    .font(.system(size: 14))
            }
            .keylineTint(severityColor(context.attributes.severity))
        }
    }
    
    // Format time to show how much time remains
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if now > date {
            return "Ended"
        }
        
        let components = calendar.dateComponents([.hour, .minute], from: now, to: date)
        
        if let hours = components.hour, hours > 0 {
            return "\(hours)h \(components.minute ?? 0)m"
        } else {
            return "\(components.minute ?? 0)m"
        }
    }
    
    // Get color based on severity
    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "extreme":
            return .red
        case "severe":
            return .orange
        case "moderate":
            return .yellow
        default:
            return .blue
        }
    }
}

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<WeatherAlertAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(severityColor(context.attributes.severity))
                    .font(.system(size: 20))
                
                Text(context.state.eventType)
                    .bold()
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Until \(timeFormatter.string(from: context.state.endTime))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Location and Alert Details
            VStack(alignment: .leading, spacing: 8) {
                Text(context.attributes.location)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(context.state.headline)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                
                // Progress bar showing time remaining
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                        .overlay(
                            Capsule()
                                .fill(severityColor(context.attributes.severity))
                                .frame(width: progressWidth(geo.size.width))
                                .frame(height: 4),
                            alignment: .leading
                        )
                }
                .frame(height: 4)
            }
        }
        .padding()
        .background(backgroundColor(context.attributes.severity))
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
        let totalDuration = context.state.endTime.timeIntervalSince(context.state.startTime)
        let elapsed = Date().timeIntervalSince(context.state.startTime)
        let progress = min(max(1 - (elapsed / totalDuration), 0), 1)
        return totalWidth * CGFloat(progress)
    }
    
    private func backgroundColor(_ severity: String) -> LinearGradient {
        let baseColor = severityColor(severity)
        
        return LinearGradient(
            colors: [
                baseColor.opacity(0.9),
                baseColor.opacity(0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "extreme":
            return .red
        case "severe":
            return .orange
        case "moderate":
            return .yellow
        default:
            return .blue
        }
    }
}
