# Testing Guide

## Introduction

This guide outlines the testing strategy for the iOS Weather Dashboard application, including unit tests, UI tests, and widget tests.

## Testing Architecture

The app follows a testable architecture with clear separation of concerns:

- **Models**: Pure data structures
- **ViewModels**: Business logic and state management
- **Views**: UI presentation
- **Services**: API communication and data handling

## Testing Tools

- **XCTest**: Apple's native testing framework
- **Combine Testing**: For testing asynchronous operations
- **ViewInspector**: For testing SwiftUI views
- **SnapshotTesting**: For UI consistency verification

## Unit Testing

### ViewModel Tests

Test files: `WeatherViewModelTests.swift`

```swift
class WeatherViewModelTests: XCTestCase {
    var viewModel: WeatherViewModel!
    var mockAPIService: MockWeatherAPIService!
    
    override func setUp() {
        super.setUp()
        mockAPIService = MockWeatherAPIService()
        viewModel = WeatherViewModel(apiService: mockAPIService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockAPIService = nil
        super.tearDown()
    }
    
    func testFetchWeatherDataSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Fetch weather data")
        let mockData = WeatherData(daily: [mockDailyForecast()], location: "Test City")
        mockAPIService.mockWeatherData = mockData
        
        // When
        viewModel.fetchWeatherData(for: "47.6062,-122.3321")
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.viewModel.isLoading)
            XCTAssertEqual(self.viewModel.weatherData.location, "Test City")
            XCTAssertEqual(self.viewModel.weatherData.daily.count, 1)
            XCTAssertNil(self.viewModel.error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchWeatherDataFailure() {
        // Given
        let expectation = XCTestExpectation(description: "Fetch weather data error")
        mockAPIService.shouldFail = true
        mockAPIService.mockError = APIError.networkError
        
        // When
        viewModel.fetchWeatherData(for: "47.6062,-122.3321")
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.viewModel.isLoading)
            XCTAssertTrue(self.viewModel.weatherData.daily.isEmpty)
            XCTAssertNotNil(self.viewModel.error)
            XCTAssertEqual(self.viewModel.error, APIError.networkError.localizedDescription)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // Helper methods
    private func mockDailyForecast() -> DailyForecast {
        return DailyForecast(
            id: "day-1",
            day: "Monday",
            fullDay: "Monday",
            date: Date(),
            tempHigh: 75,
            tempLow: 65,
            precipitation: Precipitation(chance: 30),
            uvIndex: 5,
            wind: Wind(speed: 10, direction: "NW"),
            icon: "sun",
            detailedForecast: "Sunny with a high near 75. Northwest wind around 10 mph.",
            shortForecast: "Sunny"
        )
    }
}
```

### Service Tests

Test files: `WeatherAPIServiceTests.swift`

```swift
class WeatherAPIServiceTests: XCTestCase {
    var apiService: WeatherAPIService!
    var mockURLSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        apiService = WeatherAPIService(session: mockURLSession)
    }
    
    override func tearDown() {
        apiService = nil
        mockURLSession = nil
        super.tearDown()
    }
    
    func testFetchWeatherDataSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Fetch weather data")
        let mockData = loadMockData(filename: "weather_response")
        mockURLSession.mockData = mockData
        mockURLSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        // When
        let cancellable = apiService.fetchWeatherData(for: "47.6062,-122.3321")
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Expected success but got error: \(error)")
                }
                expectation.fulfill()
            }, receiveValue: { weatherData in
                // Then
                XCTAssertEqual(weatherData.location, "Seattle, WA")
                XCTAssertEqual(weatherData.daily.count, 7)
            })
        
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
    
    func testFetchWeatherDataFailure() {
        // Given
        let expectation = XCTestExpectation(description: "Fetch weather data error")
        mockURLSession.mockError = NSError(domain: "test", code: -1, userInfo: nil)
        
        // When
        let cancellable = apiService.fetchWeatherData(for: "47.6062,-122.3321")
            .sink(receiveCompletion: { completion in
                // Then
                if case .failure(let error) = completion {
                    XCTAssertTrue(error is APIError)
                    expectation.fulfill()
                } else {
                    XCTFail("Expected failure but got success")
                }
            }, receiveValue: { _ in
                XCTFail("Expected no value")
            })
        
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
    
    // Helper method to load mock data
    private func loadMockData(filename: String) -> Data {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: filename, withExtension: "json")!
        return try! Data(contentsOf: url)
    }
}

// Mock URLSession for testing
class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    func dataTaskPublisher(for url: URL) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        if let error = mockError {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return Just((data: mockData ?? Data(), response: mockResponse ?? HTTPURLResponse()))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

// Protocol for URLSession to allow mocking
protocol URLSessionProtocol {
    func dataTaskPublisher(for url: URL) -> AnyPublisher<(data: Data, response: URLResponse), Error>
}

extension URLSession: URLSessionProtocol {
    func dataTaskPublisher(for url: URL) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        return self.dataTaskPublisher(for: url)
            .map { (data: $0.data, response: $0.response) }
            .eraseToAnyPublisher()
    }
}
```

### Utility Tests

Test files: `WeatherUtilsTests.swift`

```swift
class WeatherUtilsTests: XCTestCase {
    func testFahrenheitToCelsius() {
        // Given
        let fahrenheit = 77.0
        let expectedCelsius = 25.0
        
        // When
        let result = WeatherUtils.fahrenheitToCelsius(fahrenheit)
        
        // Then
        XCTAssertEqual(result, expectedCelsius, accuracy: 0.01)
    }
    
    func testCelsiusToFahrenheit() {
        // Given
        let celsius = 25.0
        let expectedFahrenheit = 77.0
        
        // When
        let result = WeatherUtils.celsiusToFahrenheit(celsius)
        
        // Then
        XCTAssertEqual(result, expectedFahrenheit, accuracy: 0.01)
    }
    
    func testCalculateHeatIndex() {
        // Given
        let temperature = 90.0
        let humidity = 60.0
        
        // When
        let result = WeatherUtils.calculateHeatIndex(temperature: temperature, humidity: humidity)
        
        // Then
        XCTAssertGreaterThan(result, temperature, "Heat index should be higher than actual temperature in hot humid conditions")
    }
    
    func testCalculateWindChill() {
        // Given
        let temperature = 20.0
        let windSpeed = 15.0
        
        // When
        let result = WeatherUtils.calculateWindChill(temperature: temperature, windSpeed: windSpeed)
        
        // Then
        XCTAssertLessThan(result, temperature, "Wind chill should be lower than actual temperature in cold windy conditions")
    }
}
```

## UI Testing

### SwiftUI View Tests (using ViewInspector)

Test files: `WeatherCardViewTests.swift`

```swift
import XCTest
import ViewInspector
@testable import WeatherApp

extension WeatherCardView: Inspectable {}

class WeatherCardViewTests: XCTestCase {
    var viewModel: WeatherViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = WeatherViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testWeatherCardDisplaysCorrectInfo() throws {
        // Given
        let forecast = DailyForecast(
            id: "day-1",
            day: "Monday",
            fullDay: "Monday",
            date: Date(),
            tempHigh: 75,
            tempLow: 65,
            precipitation: Precipitation(chance: 30),
            uvIndex: 5,
            wind: Wind(speed: 10, direction: "NW"),
            icon: "sun",
            detailedForecast: "Sunny",
            shortForecast: "Sunny"
        )
        
        // When
        let view = WeatherCardView(forecast: forecast)
            .environmentObject(viewModel)
        
        // Then
        let dayText = try view.inspect().find(viewWithId: "dayLabel").text().string()
        XCTAssertEqual(dayText, "Monday")
        
        let highTemp = try view.inspect().find(viewWithId: "highTemp").text().string()
        XCTAssertEqual(highTemp, "75°")
        
        let lowTemp = try view.inspect().find(viewWithId: "lowTemp").text().string()
        XCTAssertEqual(lowTemp, "65°")
        
        let precipitation = try view.inspect().find(viewWithId: "precipitation").text().string()
        XCTAssertEqual(precipitation, "30%")
    }
    
    func testCardSelectionChangesAppearance() throws {
        // Given
        let forecast = DailyForecast(
            id: "day-1",
            day: "Monday",
            fullDay: "Monday",
            date: Date(),
            tempHigh: 75,
            tempLow: 65,
            precipitation: Precipitation(chance: 30),
            uvIndex: 5,
            wind: Wind(speed: 10, direction: "NW"),
            icon: "sun",
            detailedForecast: "Sunny",
            shortForecast: "Sunny"
        )
        
        // When
        let view = WeatherCardView(forecast: forecast)
            .environmentObject(viewModel)
        
        // Then - Initially not selected
        let button = try view.inspect().button()
        let initialBackground = try button.backgroundColor()
        
        // Simulate selection
        viewModel.setSelectedDay("day-1")
        
        // Background should change
        let selectedBackground = try button.backgroundColor()
        XCTAssertNotEqual(initialBackground, selectedBackground)
    }
}
```

## Widget Testing

Test files: `WeatherWidgetTests.swift`

```swift
import XCTest
import WidgetKit
@testable import WeatherWidgetExtension

class WeatherWidgetTests: XCTestCase {
    func testWidgetProvider() {
        // Given
        let provider = WeatherWidgetProvider()
        
        // When - Test placeholder
        let placeholderEntry = provider.placeholder(in: .init())
        
        // Then
        XCTAssertEqual(placeholderEntry.location, "Seattle, WA")
        XCTAssertEqual(placeholderEntry.temperature, 72)
    }
    
    func testTimelineGeneration() {
        // Given
        let provider = WeatherWidgetProvider()
        let expectation = XCTestExpectation(description: "Timeline generation")
        
        // When
        provider.getTimeline(in: .init()) { timeline in
            // Then
            XCTAssertEqual(timeline.entries.count, 1)
            XCTAssertEqual(timeline.entries[0].location, "Seattle, WA")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
```

## Test Coverage

Aim for high test coverage in the following areas:

1. **Core Logic**: ViewModels, Services, Utilities (90%+ coverage)
2. **Data Models**: Model structures and transformations (80%+ coverage)
3. **UI Components**: Critical user interface elements (70%+ coverage)
4. **Widget Logic**: Timeline providers and entry generation (80%+ coverage)

## Running Tests

### Command Line

```bash
xcodebuild test -project WeatherApp.xcodeproj -scheme WeatherApp -destination "platform=iOS Simulator,name=iPhone 14"
```

### Xcode Test Navigator

1. Open the project in Xcode
2. Select the Test Navigator tab (⌘6)
3. Click the run button next to the test suite or individual test

## Continuous Integration

The project is configured for CI testing with the following setup:

1. **GitHub Actions**: Runs all tests on pull requests and main branch commits
2. **Fastlane**: Provides test automation and reporting
3. **Test Reports**: Publishes results to the project dashboard

## Best Practices

1. **Test Isolation**: Each test should be independent and not rely on state from other tests
2. **Mock External Dependencies**: Use mock objects for network calls and system services
3. **Test Edge Cases**: Include tests for error conditions and boundary values
4. **Readable Tests**: Follow the Given-When-Then pattern for clarity
5. **Test Performance**: Use performance tests for critical operations
6. **Keep Tests Updated**: Update tests when code changes

## Test Data

Mock data files are located in the test bundle under `TestData/` and include:

- `weather_response.json`: Sample NWS API response
- `weather_forecast.json`: Sample forecast data
- `weather_alerts.json`: Sample weather alerts

## Troubleshooting Common Test Issues

1. **Asynchronous Testing**: Use expectations for testing async code
2. **UI Testing Flakiness**: Add appropriate delays or use UI querying
3. **Widget Timeline Testing**: Ensure consistent date handling
4. **Core Data Testing**: Use in-memory store for tests