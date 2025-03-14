import XCTest
import Combine
@testable import WeatherApp

class WeatherViewModelTests: XCTestCase {
    var viewModel: WeatherViewModel!
    var mockWeatherService: MockWeatherService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        mockWeatherService = MockWeatherService()
        viewModel = WeatherViewModel(weatherService: mockWeatherService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockWeatherService = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    func testFetchWeatherDataSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Fetch weather data")
        
        // When
        viewModel.fetchWeatherData(for: "37.7749,-122.4194")
        
        // Then
        viewModel.$weatherData
            .dropFirst() // Skip initial empty value
            .sink { weatherData in
                XCTAssertFalse(weatherData.daily.isEmpty, "Daily forecast should not be empty")
                XCTAssertFalse(weatherData.hourly.isEmpty, "Hourly forecast should not be empty")
                XCTAssertEqual(weatherData.location, "San Francisco, CA", "Location should match expected value")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testTemperatureConversion() {
        // Given
        let celsius = 20.0
        
        // Test Celsius to Fahrenheit
        viewModel.preferences.unit = .fahrenheit
        let fahrenheit = viewModel.getTemperatureString(celsius)
        
        // Then
        XCTAssertEqual(fahrenheit, "68°F", "20°C should convert to 68°F")
        
        // Test keeping as Celsius
        viewModel.preferences.unit = .celsius
        let celsiusString = viewModel.getTemperatureString(celsius)
        
        // Then
        XCTAssertEqual(celsiusString, "20°C", "20°C should remain as 20°C")
    }
    
    func testWeatherIconMapping() {
        // Test various weather conditions
        XCTAssertEqual(viewModel.getSystemIcon(from: "clear-day"), "sun.max.fill")
        XCTAssertEqual(viewModel.getSystemIcon(from: "partly-cloudy-night"), "cloud.moon.fill")
        XCTAssertEqual(viewModel.getSystemIcon(from: "rain"), "cloud.rain.fill")
        XCTAssertEqual(viewModel.getSystemIcon(from: "snow"), "cloud.snow.fill")
        XCTAssertEqual(viewModel.getSystemIcon(from: "unknown"), "cloud.fill") // Default case
    }
    
    func testCacheExpiration() {
        // Given
        let expectation = XCTestExpectation(description: "Cache save and load")
        let weatherCacheService = WeatherCacheService()
        let location = "Test Location"
        let weatherData = createTestWeatherData()
        
        // When - Save to cache
        weatherCacheService.save(weatherData: weatherData, for: location)
        
        // Then - Verify it can be loaded back
        if let cachedData = weatherCacheService.loadCachedData(for: location) {
            XCTAssertEqual(cachedData.location, weatherData.location)
            XCTAssertEqual(cachedData.daily.count, weatherData.daily.count)
            XCTAssertEqual(cachedData.hourly.count, weatherData.hourly.count)
            expectation.fulfill()
        } else {
            XCTFail("Failed to load cached data")
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up
        weatherCacheService.clearCache(for: location)
    }
    
    // MARK: - Helper Methods
    
    private func createTestWeatherData() -> WeatherData {
        var data = WeatherData()
        data.location = "Test Location"
        
        // Create some test daily forecasts
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<3 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                let dailyForecast = DailyForecast(
                    id: "day-\(i)",
                    day: "Day \(i)",
                    fullDay: "Full Day \(i)",
                    date: date,
                    tempHigh: 25.0,
                    tempLow: 15.0,
                    precipitation: Precipitation(chance: 30),
                    uvIndex: 5,
                    wind: Wind(speed: 10, direction: "N"),
                    icon: "sun",
                    detailedForecast: "Detailed forecast",
                    shortForecast: "Short forecast",
                    humidity: 65,
                    dewpoint: 10,
                    pressure: 1012,
                    skyCover: 20
                )
                data.daily.append(dailyForecast)
            }
        }
        
        // Create some test hourly forecasts
        for i in 0..<6 {
            if let date = calendar.date(byAdding: .hour, value: i, to: today) {
                let hourlyForecast = HourlyForecast(
                    id: "hour-\(i)",
                    time: "\(i)pm",
                    temperature: 20.0,
                    icon: "sun",
                    shortForecast: "Sunny",
                    windSpeed: 8,
                    windDirection: "N",
                    isDaytime: true
                )
                data.hourly.append(hourlyForecast)
            }
        }
        
        return data
    }
}

// MARK: - Mock Weather Service

class MockWeatherService: WeatherServiceProtocol {
    func fetchWeather(for coordinates: String, unit: WeatherViewModel.UserPreferences.TemperatureUnit) -> AnyPublisher<(WeatherData, [WeatherAlert]), Error> {
        // Return mock data
        let weatherData = createMockWeatherData()
        let alerts = createMockAlerts()
        
        return Just((weatherData, alerts))
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main) // Simulate network delay
            .eraseToAnyPublisher()
    }
    
    private func createMockWeatherData() -> WeatherData {
        var data = WeatherData()
        data.location = "San Francisco, CA"
        
        // Create mock daily forecasts
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "E"
                let fullDayFormatter = DateFormatter()
                fullDayFormatter.dateFormat = "EEEE"
                
                let dailyForecast = DailyForecast(
                    id: "day-\(i)",
                    day: dayFormatter.string(from: date),
                    fullDay: fullDayFormatter.string(from: date),
                    date: date,
                    tempHigh: Double.random(in: 15...30),
                    tempLow: Double.random(in: 5...15),
                    precipitation: Precipitation(chance: Double.random(in: 0...100)),
                    uvIndex: Int.random(in: 0...11),
                    wind: Wind(speed: Double.random(in: 0...30), direction: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].randomElement() ?? "N"),
                    icon: ["sun", "cloud", "rain", "snow"].randomElement() ?? "sun",
                    detailedForecast: "Detailed forecast for \(dayFormatter.string(from: date))",
                    shortForecast: ["Sunny", "Partly cloudy", "Cloudy", "Rainy", "Snowy"].randomElement() ?? "Sunny",
                    humidity: Double.random(in: 30...90),
                    dewpoint: Double.random(in: 5...15),
                    pressure: Double.random(in: 980...1030),
                    skyCover: Double.random(in: 0...100)
                )
                data.daily.append(dailyForecast)
            }
        }
        
        // Create mock hourly forecasts
        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "ha"
        
        for i in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: i, to: today) {
                let hourlyForecast = HourlyForecast(
                    id: "hour-\(i)",
                    time: hourFormatter.string(from: date).lowercased(),
                    temperature: Double.random(in: 10...25),
                    icon: ["sun", "cloud", "rain", "snow"].randomElement() ?? "sun",
                    shortForecast: ["Sunny", "Partly cloudy", "Cloudy", "Rainy"].randomElement() ?? "Sunny",
                    windSpeed: Double.random(in: 0...20),
                    windDirection: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].randomElement() ?? "N",
                    isDaytime: (6...18).contains(calendar.component(.hour, from: date))
                )
                data.hourly.append(hourlyForecast)
            }
        }
        
        return data
    }
    
    private func createMockAlerts() -> [WeatherAlert] {
        // Random chance to include alerts
        if Bool.random() {
            let now = Date()
            return [
                WeatherAlert(
                    id: "alert-1",
                    headline: "Test Alert",
                    description: "This is a test weather alert",
                    severity: ["moderate", "severe"].randomElement()!,
                    event: ["Thunderstorm", "Heat Advisory"].randomElement()!,
                    start: now,
                    end: now.addingTimeInterval(3600 * 24) // 24 hours later
                )
            ]
        } else {
            return []
        }
    }
}
