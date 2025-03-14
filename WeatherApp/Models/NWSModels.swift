import Foundation

// MARK: - NWS API Response Models
// Models for parsing National Weather Service API responses

// Points endpoint response
struct NWSPointsResponse: Decodable {
    let properties: NWSPointProperties
}

struct NWSPointProperties: Decodable {
    let gridId: String
    let gridX: Int
    let gridY: Int
    let forecast: String
    let forecastHourly: String
    let relativeLocation: NWSRelativeLocation?
    let timeZone: String?
}

struct NWSRelativeLocation: Decodable {
    let properties: NWSLocationProperties
}

struct NWSLocationProperties: Decodable {
    let city: String
    let state: String
}

// Forecast endpoint response
struct NWSForecastResponse: Decodable {
    let properties: NWSForecastProperties
}

struct NWSForecastProperties: Decodable {
    let periods: [NWSForecastPeriod]
    let updated: String
}

struct NWSForecastPeriod: Decodable {
    let number: Int
    let name: String
    let startTime: String
    let endTime: String
    let isDaytime: Bool
    let temperature: Int
    let temperatureUnit: String
    let windSpeed: String
    let windDirection: String
    let icon: String
    let shortForecast: String
    let detailedForecast: String
    let probabilityOfPrecipitation: NWSPrecipitation?
    let relativeHumidity: NWSHumidity?
}

struct NWSPrecipitation: Decodable {
    let value: Int?
}

struct NWSHumidity: Decodable {
    let value: Int?
}

// Alerts endpoint response
struct NWSAlertResponse: Decodable {
    let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Decodable {
    let properties: NWSAlertProperties
}

struct NWSAlertProperties: Decodable {
    let id: String
    let event: String
    let headline: String?
    let description: String
    let severity: String
    let effective: String
    let onset: String
    let expires: String
}
