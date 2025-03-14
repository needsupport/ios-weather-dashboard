import SwiftUI\n\n/// Main dashboard view displaying weather information\nstruct WeatherDashboardView: View {\n    @EnvironmentObject var viewModel: WeatherViewModel\n    @State private var selectedTab = 0\n    \n    var body: some View {\n        ScrollView {\n            VStack(spacing: 20) {\n                // Current weather summary\n                CurrentWeatherView()\n                    .padding(.horizontal)\n                \n                // Tab selector for different views\n                tabSelector\n                \n                // Content based on selected tab\n                tabContent\n            }\n            .padding(.vertical)\n        }\n        .refreshable {\n            viewModel.refreshWeather()\n        }\n    }\n    \n    /// Tab selector for different content views\n    var tabSelector: some View {\n        HStack {\n            ForEach(0..<3) { index in\n                Button(action: {\n                    selectedTab = index\n                }) {\n                    Text(tabTitle(for: index))\n                        .fontWeight(selectedTab == index ? .bold : .regular)\n                        .padding(.vertical, 8)\n                        .padding(.horizontal, 12)\n                        .background(\n                            selectedTab == index ?\n                            RoundedRectangle(cornerRadius: 20)\n                                .fill(Color.blue.opacity(0.2)) :\n                            RoundedRectangle(cornerRadius: 20)\n                                .fill(Color.clear)\n                        )\n                }\n                .buttonStyle(PlainButtonStyle())\n            }\n        }\n        .padding(.horizontal)\n    }\n    \n    /// Content based on selected tab\n    @ViewBuilder\n    var tabContent: some View {\n        switch selectedTab {\n        case 0:\n            dailyForecastView\n        case 1:\n            hourlyForecastView\n        case 2:\n            alertsView\n        default:\n            dailyForecastView\n        }\n    }\n    \n    /// Daily forecast grid view\n    var dailyForecastView: some View {\n        VStack(spacing: 16) {\n            // Weather chart\n            WeatherChartView()\n                .padding(.horizontal)\n            \n            // Daily forecast cards\n            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {\n                ForEach(viewModel.weatherData.daily) { day in\n                    WeatherCardView(forecast: day)\n                        .onTapGesture {\n                            viewModel.setSelectedDay(day.id)\n                        }\n                }\n            }\n            .padding(.horizontal)\n        }\n    }\n    \n    /// Hourly forecast view\n    var hourlyForecastView: some View {\n        VStack(alignment: .leading, spacing: 8) {\n            Text(\"Hourly Forecast\")\n                .font(.headline)\n                .padding(.horizontal)\n            \n            ScrollView(.horizontal, showsIndicators: false) {\n                HStack(spacing: 16) {\n                    ForEach(viewModel.weatherData.hourly) { hour in\n                        HourlyForecastItemView(forecast: hour)\n                    }\n                }\n                .padding(.horizontal)\n            }\n            \n            Divider()\n                .padding(.vertical, 8)\n            \n            Text(\"Next 24 Hours Details\")\n                .font(.headline)\n                .padding(.horizontal)\n            \n            DetailedHourlyView(hourlyData: viewModel.weatherData.hourly)\n                .padding(.horizontal)\n        }\n    }\n    \n    /// Weather alerts view\n    var alertsView: some View {\n        VStack(alignment: .leading, spacing: 16) {\n            Text(\"Weather Alerts\")\n                .font(.headline)\n                .padding(.horizontal)\n            \n            if viewModel.alerts.isEmpty {\n                VStack(spacing: 12) {\n                    Image(systemName: \"checkmark.circle\")\n                        .font(.system(size: 40))\n                        .foregroundColor(.green)\n                    \n                    Text(\"No active weather alerts\")\n                        .font(.subheadline)\n                        .foregroundColor(.secondary)\n                }\n                .frame(maxWidth: .infinity, minHeight: 200)\n            } else {\n                ForEach(viewModel.alerts) { alert in\n                    AlertCardView(alert: alert)\n                }\n            }\n        }\n        .padding(.horizontal)\n    }\n    \n    /// Get tab title based on index\n    func tabTitle(for index: Int) -> String {\n        switch index {\n        case 0: return \"Forecast\"\n        case 1: return \"Hourly\"\n        case 2: return \"Alerts\"\n        default: return \"\"\n        }\n    }\n}\n\n/// Hourly forecast item view\nstruct HourlyForecastItemView: View {\n    let forecast: HourlyForecast\n    @EnvironmentObject var viewModel: WeatherViewModel\n    \n    var body: some View {\n        VStack(spacing: 8) {\n            Text(forecast.time)\n                .font(.caption)\n                .foregroundColor(.secondary)\n            \n            weatherIcon\n                .font(.system(size: 22))\n            \n            Text(\"\\(Int(forecast.temperature))\u00b0\\(viewModel.preferences.unit.rawValue)\")\n                .font(.headline)\n            \n            HStack(spacing: 4) {\n                Image(systemName: \"wind\")\n                    .font(.system(size: 10))\n                Text(\"\\(Int(forecast.windSpeed))\")\n                    .font(.caption2)\n            }\n            .foregroundColor(.secondary)\n        }\n        .frame(width: 60, height: 120)\n        .padding(8)\n        .background(\n            RoundedRectangle(cornerRadius: 12)\n                .fill(Color(.systemBackground))\n                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)\n        )\n    }\n    \n    @ViewBuilder\n    var weatherIcon: some View {\n        switch forecast.icon {\n        case \"sun\":\n            Image(systemName: \"sun.max.fill\").symbolRenderingMode(.multicolor)\n        case \"cloud\":\n            Image(systemName: \"cloud.fill\").symbolRenderingMode(.multicolor)\n        case \"rain\":\n            Image(systemName: \"cloud.rain.fill\").symbolRenderingMode(.multicolor)\n        case \"snow\":\n            Image(systemName: \"snow\").symbolRenderingMode(.multicolor)\n        default:\n            Image(systemName: \"cloud.fill\").symbolRenderingMode(.multicolor)\n        }\n    }\n}\n\n/// Detailed hourly forecast view\nstruct DetailedHourlyView: View {\n    let hourlyData: [HourlyForecast]\n    \n    var body: some View {\n        VStack(spacing: 16) {\n            ForEach(hourlyData.prefix(12)) { hour in\n                HStack {\n                    Text(hour.time)\n                        .frame(width: 60, alignment: .leading)\n                    \n                    Image(systemName: getSystemIcon(for: hour.icon))\n                        .symbolRenderingMode(.multicolor)\n                        .frame(width: 30)\n                    \n                    Text(hour.shortForecast)\n                        .lineLimit(1)\n                        .frame(maxWidth: .infinity, alignment: .leading)\n                    \n                    Text(\"\\(Int(hour.temperature))\u00b0\")\n                        .fontWeight(.semibold)\n                        .frame(width: 40, alignment: .trailing)\n                }\n                .font(.subheadline)\n                \n                if hourlyData.firstIndex(where: { $0.id == hour.id }) != hourlyData.prefix(12).count - 1 {\n                    Divider()\n                }\n            }\n        }\n        .padding()\n        .background(\n            RoundedRectangle(cornerRadius: 12)\n                .fill(Color(.systemBackground))\n                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)\n        )\n    }\n    \n    func getSystemIcon(for iconType: String) -> String {\n        switch iconType {\n        case \"sun\": return \"sun.max.fill\"\n        case \"cloud\": return \"cloud.fill\"\n        case \"rain\": return \"cloud.rain.fill\"\n        case \"snow\": return \"snow\"\n        default: return \"cloud.fill\"\n        }\n    }\n}\n\n/// Alert card view\nstruct AlertCardView: View {\n    let alert: WeatherAlert\n    @State private var isExpanded = false\n    \n    var body: some View {\n        VStack(alignment: .leading, spacing: 8) {\n            HStack {\n                alertIcon\n                \n                VStack(alignment: .leading, spacing: 4) {\n                    Text(alert.event)\n                        .font(.headline)\n                    \n                    Text(alert.headline)\n                        .font(.subheadline)\n                        .lineLimit(isExpanded ? nil : 1)\n                }\n                \n                Spacer()\n                \n                Button(action: {\n                    withAnimation {\n                        isExpanded.toggle()\n                    }\n                }) {\n                    Image(systemName: isExpanded ? \"chevron.up\" : \"chevron.down\")\n                        .foregroundColor(.primary)\n                }\n            }\n            \n            if isExpanded {\n                Divider()\n                \n                Text(alert.description)\n                    .font(.body)\n                    .foregroundColor(.secondary)\n                \n                HStack {\n                    Label(\n                        formatDate(alert.start),\n                        systemImage: \"clock\"\n                    )\n                    \n                    Spacer()\n                    \n                    if let end = alert.end {\n                        Label(\n                            formatDate(end),\n                            systemImage: \"clock.badge.checkmark\"\n                        )\n                    }\n                }\n                .font(.caption)\n                .foregroundColor(.secondary)\n            }\n        }\n        .padding()\n        .background(\n            RoundedRectangle(cornerRadius: 12)\n                .fill(alertBackgroundColor)\n                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)\n        )\n    }\n    \n    /// Alert background color based on severity\n    var alertBackgroundColor: Color {\n        switch alert.severity.lowercased() {\n        case \"extreme\":\n            return Color.red.opacity(0.2)\n        case \"severe\":\n            return Color.orange.opacity(0.2)\n        case \"moderate\":\n            return Color.yellow.opacity(0.2)\n        default:\n            return Color.blue.opacity(0.2)\n        }\n    }\n    \n    /// Alert icon based on severity\n    @ViewBuilder\n    var alertIcon: some View {\n        switch alert.severity.lowercased() {\n        case \"extreme\":\n            Image(systemName: \"exclamationmark.triangle.fill\")\n                .foregroundColor(.red)\n                .font(.title2)\n        case \"severe\":\n            Image(systemName: \"exclamationmark.triangle.fill\")\n                .foregroundColor(.orange)\n                .font(.title2)\n        case \"moderate\":\n            Image(systemName: \"exclamationmark.circle.fill\")\n                .foregroundColor(.yellow)\n                .font(.title2)\n        default:\n            Image(systemName: \"info.circle.fill\")\n                .foregroundColor(.blue)\n                .font(.title2)\n        }\n    }\n    \n    /// Format date to readable string\n    func formatDate(_ date: Date) -> String {\n        let formatter = DateFormatter()\n        formatter.dateStyle = .short\n        formatter.timeStyle = .short\n        return formatter.string(from: date)\n    }\n}\n\nstruct WeatherDashboardView_Previews: PreviewProvider {\n    static var previews: some View {\n        WeatherDashboardView()\n            .environmentObject(WeatherViewModel())\n    }\n}