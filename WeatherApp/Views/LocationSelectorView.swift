import SwiftUI
import CoreLocation

struct LocationSelectorView: View {
    let cityCoordinates: [String: String]
    let onLocationSelected: (String, String) -> Void
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingCustomLocation = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search city...", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchText) { _ in
                            isSearching = !searchText.isEmpty
                        }
                    
                    if isSearching {
                        Button(action: {
                            searchText = ""
                            isSearching = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                if isSearching && filteredCities.isEmpty {
                    // No results
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                        
                        Text("No cities found")
                            .font(.headline)
                        
                        Text("Try a different search or add a custom location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showingCustomLocation = true
                        }) {
                            Text("Add Custom Location")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    // City list
                    List {
                        // Current location option
                        Button(action: {
                            LocationManager.shared.requestLocationOnce { location in
                                if let location = location {
                                    let coordinates = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
                                    onLocationSelected("Current Location", coordinates)
                                    dismiss()
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text("Current Location")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // City list
                        Section(header: Text(isSearching ? "Search Results" : "Popular Cities")) {
                            ForEach(filteredCities, id: \.key) { city, coordinates in
                                Button(action: {
                                    onLocationSelected(city, coordinates)
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(city)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Add custom location button
                        Section {
                            Button(action: {
                                showingCustomLocation = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Add Custom Location")
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationBarTitle("Select Location", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .sheet(isPresented: $showingCustomLocation) {
                CustomLocationView { name, coords in
                    onLocationSelected(name, coords)
                    dismiss()
                }
            }
        }
    }
    
    // Filtered cities based on search text
    private var filteredCities: [(key: String, value: String)] {
        if searchText.isEmpty {
            return Array(cityCoordinates).sorted { $0.key < $1.key }
        } else {
            return cityCoordinates.filter { $0.key.lowercased().contains(searchText.lowercased()) }
                .sorted { $0.key < $1.key }
        }
    }
}

// MARK: - Custom Location View
struct CustomLocationView: View {
    @State private var locationName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss
    var onLocationAdded: (String, String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Location Name (e.g. My Home)", text: $locationName)
                        .autocapitalization(.words)
                    
                    TextField("Latitude (e.g. 37.7749)", text: $latitude)
                        .keyboardType(.decimalPad)
                    
                    TextField("Longitude (e.g. -122.4194)", text: $longitude)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button(action: submitLocation) {
                        Text("Add Location")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .background(isFormValid ? Color.blue : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationBarTitle("Custom Location", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert(isPresented: $isShowingError) {
                Alert(
                    title: Text("Invalid Coordinates"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var isFormValid: Bool {
        !locationName.isEmpty && !latitude.isEmpty && !longitude.isEmpty
    }
    
    private func submitLocation() {
        guard let lat = Double(latitude), let lon = Double(longitude) else {
            errorMessage = "Please enter valid numbers for latitude and longitude"
            isShowingError = true
            return
        }
        
        // Validate latitude range (-90 to 90)
        guard lat >= -90 && lat <= 90 else {
            errorMessage = "Latitude must be between -90 and 90"
            isShowingError = true
            return
        }
        
        // Validate longitude range (-180 to 180)
        guard lon >= -180 && lon <= 180 else {
            errorMessage = "Longitude must be between -180 and 180"
            isShowingError = true
            return
        }
        
        let coordinates = "\(lat),\(lon)"
        onLocationAdded(locationName, coordinates)
    }
}

// MARK: - Location Manager for getting current location
class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var locationCallback: ((CLLocation?) -> Void)?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func requestLocationOnce(completion: @escaping (CLLocation?) -> Void) {
        locationCallback = completion
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            completion(nil) // Permission denied
        @unknown default:
            completion(nil)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationCallback?(locations.first)
        locationCallback = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        locationCallback?(nil)
        locationCallback = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            locationCallback?(nil)
            locationCallback = nil
        }
    }
}

// MARK: - Preview
struct LocationSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        LocationSelectorView(
            cityCoordinates: [
                "New York, NY": "40.7128,-74.0060",
                "Los Angeles, CA": "34.0522,-118.2437",
                "Chicago, IL": "41.8781,-87.6298",
                "San Francisco, CA": "37.7749,-122.4194"
            ],
            onLocationSelected: { _, _ in }
        )
    }
}