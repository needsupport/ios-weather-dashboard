import XCTest
@testable import WeatherApp

class WeatherCacheServiceTests: XCTestCase {
    
    var cacheService: WeatherCacheService!
    var mockWeatherData: WeatherData!
    
    override func setUp() {
        super.setUp()
        cacheService = WeatherCacheService()
        mockWeatherData = createMockWeatherData()
        
        // Clear any existing cache before tests
        cacheService.clearCache()
    }
    
    override func tearDown() {
        cacheService.clearCache()
        cacheService = nil
        mockWeatherData = nil
        super.tearDown()
    }
    
    func testSaveAndLoadCache() {
        // Given
        let locationName = "Test City"
        
        // When
        cacheService.save(weatherData: mockWeatherData, for: locationName)
        let cachedData = cacheService.loadCachedData(for: locationName)
        
        // Then
        XCTAssertNotNil(cachedData, "Cache should contain data after saving")
        XCTAssertEqual(cachedData?.location, mockWeatherData.location, "Cached location should match original")
        XCTAssertEqual(cachedData?.daily.count, mockWeatherData.daily.count, "Cached daily forecast count should match original")
        XCTAssertEqual(cachedData?.hourly.count, mockWeatherData.hourly.count, "Cached hourly forecast count should match original")
    }
    
    func testCacheExpiration() {
        // This would ideally use a time-travel mechanism or dependency injection for date
        // For now, we'll just ensure our cache mechanism works
        
        // Given
        let locationName = "Expiration Test"
        
        // When
        cacheService.save(weatherData: mockWeatherData, for: locationName)
        
        // Then
        let cachedData = cacheService.loadCachedData(for: locationName)
        XCTAssertNotNil(cachedData, "Cache should be valid immediately after saving")
        
        // Note: We can't easily test expiration without mocking time
    }
    
    func testClearCache() {
        // Given
        let locationName1 = "City One"
        let locationName2 = "City Two"
        
        // When
        cacheService.save(weatherData: mockWeatherData, for: locationName1)
        cacheService.save(weatherData: mockWeatherData, for: locationName2)
        
        // Clear specific location
        cacheService.clearCache(for: locationName1)
        
        // Then
        XCTAssertNil(cacheService.loadCachedData(for: locationName1), "Cache for location1 should be cleared")
        XCTAssertNotNil(cacheService.loadCachedData(for: locationName2), "Cache for location2 should still exist")
        
        // When - clear all caches
        cacheService.clearCache()
        
        // Then
        XCTAssertNil(cacheService.loadCachedData(for: locationName2), "All caches should be cleared")
    }
    
    func testMultipleLocations() {
        // Given
        let locationNames = ["New York", "London", "Tokyo", "Sydney"]
        
        // When
        for name in locationNames {
            var tempData = mockWeatherData
            tempData.location = name
            cacheService.save(weatherData: tempData, for: name)
        }
        
        // Then
        for name in locationNames {
            let cachedData = cacheService.loadCachedData(for: name)
            XCTAssertNotNil(cachedData, "Cache should exist for \(name)")
            XCTAssertEqual(cachedData?.location, name, "Cached location name should match")
        }
    }
    
    // Helper method to create mock weather data
    private func createMockWeatherData() -> WeatherData {
        var data = WeatherData()
        data.location = "Mock City"
        
        // Create some mock daily forecasts
        for i in 0..<7 {
            let forecast = DailyForecast(
                id: "day-\(i)",
                day: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i % 7],
                fullDay: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][i % 7],
                date: Date().addingTimeInterval(Double(i) * 86400),
                tempHigh: 20.0 + Double(i),
                tempLow: 10.0 + Double(i),
                precipitation: Precipitation(chance: Double(i * 10)),
                uvIndex: i + 2,
                wind: Wind(speed: 10.0 + Double(i), direction: "NW"),
                icon: ["sun", "cloud", "rain", "snow"][i % 4],
                detailedForecast: "Detailed forecast for day \(i)",
                shortForecast: ["Sunny", "Cloudy", "Rainy", "Snowy"][i % 4],
                humidity: 60.0 + Double(i),
                dewpoint: 8.0 + Double(i),
                pressure: 1013.0 + Double(i),
                skyCover: 20.0 + Double(i * 10)
            )
            
            data.daily.append(forecast)
        }
        
        // Create some mock hourly forecasts
        for i in 0..<24 {
            let hour = i % 12 + 1
            let amPm = i < 12 ? "am" : "pm"
            
            let hourlyForecast = HourlyForecast(
                id: "hour-\(i)",
                time: "\(hour)\(amPm)",
                temperature: 15.0 + Double(i % 10),
                icon: ["sun", "cloud", "rain", "snow"][i % 4],
                shortForecast: ["Clear", "Partly Cloudy", "Rain", "Snow"][i % 4],
                windSpeed: 5.0 + Double(i % 5),
                windDirection: ["N", "E", "S", "W"][i % 4],
                isDaytime: i >= 6 && i < 18
            )
            
            data.hourly.append(hourlyForecast)
        }
        
        return data
    }
}
