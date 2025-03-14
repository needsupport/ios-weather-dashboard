# SwiftUI Migration Guide

## Overview

This guide helps developers familiar with React.js migrate to SwiftUI for the iOS Weather Dashboard app. It provides comparisons between React concepts and their SwiftUI counterparts.

## Component Comparison

| React.js | SwiftUI | Notes |
|----------|---------|-------|
| `Component` | `View` | Both define reusable UI elements |
| `props` | Parameters | Props in React become parameters in SwiftUI views |
| `useState` | `@State` | Local component state management |
| `useContext` | `@EnvironmentObject` | Global state accessible throughout the view hierarchy |
| `useEffect` | `.onAppear/.onDisappear` | Lifecycle-related side effects |
| `memo` | No direct equivalent | SwiftUI automatically optimizes rendering |
| `useReducer` | ObservableObject with reducers | Complex state management with actions |
| `useCallback` | Not needed | SwiftUI handles function references efficiently |
| JSX | SwiftUI DSL | Declarative syntax for UI construction |

## State Management

### React.js Example (WeatherDashboard.js)

```jsx
const [weatherData, setWeatherData] = useState({});
const [isLoading, setIsLoading] = useState(true);
const [error, setError] = useState(null);

useEffect(() => {
  fetchWeatherData(location)
    .then(data => {
      setWeatherData(data);
      setIsLoading(false);
    })
    .catch(err => {
      setError(err.message);
      setIsLoading(false);
    });
}, [location]);
```

### SwiftUI Equivalent (WeatherViewModel.swift)

```swift
class WeatherViewModel: ObservableObject {
    @Published var weatherData: WeatherData = WeatherData()
    @Published var isLoading: Bool = true
    @Published var error: String? = nil
    
    func fetchWeatherData(for location: String) {
        isLoading = true
        error = nil
        
        apiService.fetchWeatherData(for: location)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error.localizedDescription
                }
            }, receiveValue: { [weak self] weatherData in
                self?.weatherData = weatherData
            })
            .store(in: &cancellables)
    }
}
```

## Layout Comparison

### React.js Example (WeatherCard.js)

```jsx
const WeatherCard = ({ forecast, isSelected, onSelect }) => {
  return (
    <div 
      className={`weather-card ${isSelected ? 'selected' : ''}`}
      onClick={() => onSelect(forecast.id)}
    >
      <h3>{forecast.day}</h3>
      <p>{formatDate(forecast.date)}</p>
      <div className="icon">{renderIcon(forecast.icon)}</div>
      <div className="temps">
        <span className="high">{forecast.tempHigh}°</span>
        <span className="low">{forecast.tempLow}°</span>
      </div>
      <div className="precip">
        <span>{forecast.precipitation.chance}%</span>
      </div>
    </div>
  );
};
```

### SwiftUI Equivalent (WeatherCardView.swift)

```swift
struct WeatherCardView: View {
    let forecast: DailyForecast
    @EnvironmentObject var viewModel: WeatherViewModel
    
    var isSelected: Bool {
        viewModel.selectedDay == forecast.id
    }
    
    var body: some View {
        Button(action: {
            viewModel.setSelectedDay(isSelected ? nil : forecast.id)
        }) {
            VStack {
                Text(forecast.day)
                    .font(.headline)
                
                Text(formatDate(forecast.date))
                    .font(.caption)
                
                weatherIcon
                    .font(.system(size: 32))
                
                HStack {
                    Text("\(Int(forecast.tempHigh))°")
                        .font(.title3)
                    
                    Text("\(Int(forecast.tempLow))°")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Text("\(Int(forecast.precipitation.chance))%")
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Additional view helpers...
}
```

## API Integration Comparison

### React.js Example (weatherDataUtils.js)

```jsx
export async function fetchRealWeatherData(location) {
  try {
    const response = await axios.get(`${CONFIG.SERVER_URL}/api/weather/points`, {
      params: { 
        latitude: latitude, 
        longitude: longitude 
      }
    });
    
    // Process response
    return processedData;
  } catch (error) {
    throw new Error(`Failed to fetch weather data: ${error.message}`);
  }
}
```

### SwiftUI Equivalent (WeatherAPIService.swift)

```swift
func fetchWeatherData(for location: String) -> AnyPublisher<WeatherData, Error> {
    let coordinates = location.split(separator: ",")
    
    guard let pointsURL = URL(string: "\(baseURL)/weather/points") else {
        return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
    }
    
    var components = URLComponents(url: pointsURL, resolvingAgainstBaseURL: true)!
    components.queryItems = [
        URLQueryItem(name: "latitude", value: String(coordinates[0])),
        URLQueryItem(name: "longitude", value: String(coordinates[1]))
    ]
    
    guard let requestURL = components.url else {
        return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
    }
    
    return URLSession.shared.dataTaskPublisher(for: requestURL)
        .tryMap { data, response in
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                return data
            } else {
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        }
        .decode(type: PointsResponse.self, decoder: JSONDecoder())
        // Process response
        .map { response -> WeatherData in
            // Transform data and return
        }
        .eraseToAnyPublisher()
}
```

## Navigation & App Flow

### React.js Example

```jsx
function App() {
  return (
    <Router>
      <div className="app">
        <Header />
        <Switch>
          <Route path="/" exact component={WeatherDashboard} />
          <Route path="/settings" component={Settings} />
          <Route path="/details/:id" component={WeatherDetails} />
        </Switch>
      </div>
    </Router>
  );
}
```

### SwiftUI Equivalent

```swift
struct WeatherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WeatherViewModel())
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            WeatherDashboardView()
                .tabItem {
                    Label("Weather", systemImage: "cloud.sun.fill")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
    }
}
```

## Event Handling

### React.js Example

```jsx
const handleLocationSelect = (city, coordinates) => {
  setLocation({
    display: city,
    coords: coordinates
  });
  fetchWeatherData(coordinates);
};

// In JSX
<button onClick={() => handleLocationSelect(city, coordinates)}>
  {city}
</button>
```

### SwiftUI Equivalent

```swift
// In LocationSelectorView
var onLocationSelected: (String, String) -> Void

// In ContentView
LocationSelectorView(cityCoordinates: cityCoordinates) { city, coordinates in
    viewModel.fetchWeatherData(for: coordinates)
    showLocationSelector = false
}

// In LocationSelectorView
Button(action: {
    onLocationSelected(city, coordinates)
}) {
    Text(city)
}
```

## Styling Differences

### React.js with Tailwind CSS

```jsx
<div className="p-4 rounded-lg shadow-md bg-white dark:bg-gray-800">
  <h2 className="text-xl font-bold mb-2">{title}</h2>
  <p className="text-gray-600 dark:text-gray-300">{content}</p>
</div>
```

### SwiftUI Equivalent

```swift
VStack(alignment: .leading, spacing: 8) {
    Text(title)
        .font(.title2)
        .fontWeight(.bold)
    
    Text(content)
        .foregroundColor(.secondary)
}
.padding()
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 4)
)
```

## Tips for Successful Migration

1. **Start with Models**: Begin by converting your data models and state management

2. **Decouple UI and Logic**: Separate business logic from UI to make migration easier

3. **Use View Modifiers**: Learn to use SwiftUI's powerful view modifier system

4. **Leverage Previews**: Use SwiftUI's live previews for rapid development

5. **Reuse Architecture Patterns**: Many React patterns (MVVM, Redux) have SwiftUI equivalents

6. **Approach Layouts Differently**: Think in terms of stacks (VStack, HStack, ZStack) instead of flexbox

7. **Embrace Swift Features**: Take advantage of Swift's type safety and options

## Helpful Resources

- [Apple's SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui/)
- [Apple's Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Combine Framework Documentation](https://developer.apple.com/documentation/combine)
- [iOS App Dev Tutorials](https://developer.apple.com/tutorials/app-dev-training)