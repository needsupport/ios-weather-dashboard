import SwiftUI
import CoreLocation

struct SavedLocationsView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddLocationSheet = false
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationView {
            List {
                // Current location section
                Section(header: Text("CURRENT LOCATION")) {
                    Button(action: {
                        viewModel.requestCurrentLocation()
                        dismiss()
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
                }
                
                // Saved locations section
                Section(header: Text("SAVED LOCATIONS")) {
                    if viewModel.locationManager.savedLocations.isEmpty {
                        Text("No saved locations")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(viewModel.locationManager.savedLocations, id: \.id) { location in
                            Button(action: {
                                if editMode == .inactive {
                                    viewModel.loadLocationWeather(location: location)
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    Text(location.name)
                                    
                                    Spacer()
                                    
                                    if editMode == .inactive {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteLocations)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Locations")
            .navigationBarItems(
                leading: EditButton().disabled(viewModel.locationManager.savedLocations.isEmpty),
                trailing: Button(action: {
                    showingAddLocationSheet = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showingAddLocationSheet) {
                AddLocationView { locationName, coordinate in
                    viewModel.locationManager.addSavedLocation(
                        name: locationName,
                        coordinates: coordinate
                    )
                }
            }
        }
    }
    
    private func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            let location = viewModel.locationManager.savedLocations[index]
            viewModel.locationManager.removeSavedLocation(id: location.id)
        }
    }
}

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    var onLocationAdded: (String, CLLocationCoordinate2D) -> Void
    
    // Mock search completion for demo
    private func searchLocations(query: String) {
        isSearching = true
        errorMessage = nil
        
        // In a real app, this would use the Maps API or a geocoding service
        // For the demo, we'll use a hardcoded list of cities
        let cities = [
            "New York, NY": CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            "Los Angeles, CA": CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            "Chicago, IL": CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),
            "Houston, TX": CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698),
            "Phoenix, AZ": CLLocationCoordinate2D(latitude: 33.4484, longitude: -112.0740),
            "Philadelphia, PA": CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1652),
            "San Antonio, TX": CLLocationCoordinate2D(latitude: 29.4241, longitude: -98.4936),
            "San Diego, CA": CLLocationCoordinate2D(latitude: 32.7157, longitude: -117.1611),
            "Dallas, TX": CLLocationCoordinate2D(latitude: 32.7767, longitude: -96.7970),
            "San Jose, CA": CLLocationCoordinate2D(latitude: 37.3382, longitude: -121.8863)
        ]
        
        // Filter cities based on search query
        searchResults = cities.filter { $0.key.lowercased().contains(query.lowercased()) }
            .map { LocationSearchResult(id: UUID().uuidString, name: $0.key, coordinates: $0.value) }
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSearching = false
            
            if searchResults.isEmpty {
                errorMessage = "No locations found. Try a different search term."
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search for a city", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchText) { newValue in
                            if newValue.count >= 3 {
                                searchLocations(query: newValue)
                            } else {
                                searchResults = []
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if isSearching {
                    ProgressView()
                        .padding()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(searchResults) { result in
                        Button(action: {
                            onLocationAdded(result.name, result.coordinates)
                            dismiss()
                        }) {
                            Text(result.name)
                        }
                    }
                }
                
                if searchText.isEmpty {
                    // Help text when no search
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                        
                        Text("Search for a City")
                            .font(.headline)
                        
                        Text("Enter a city name to add it to your saved locations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

struct LocationSearchResult: Identifiable {
    let id: String
    let name: String
    let coordinates: CLLocationCoordinate2D
}

struct SavedLocationsView_Previews: PreviewProvider {
    static var previews: some View {
        SavedLocationsView()
            .environmentObject(WeatherViewModel())
    }
}
