import SwiftUI

struct SavedLocationsView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingAddLocationSheet = false
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                    
                    if viewModel.locationManager.savedLocations.isEmpty && !isSearching {
                        // Empty state
                        emptyState
                    } else if isSearching {
                        // Search results
                        searchResults
                    } else {
                        // Saved locations list
                        savedLocationsList
                    }
                }
            }
            .navigationTitle("Saved Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddLocationSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLocationSheet) {
                AddLocationView { name, latitude, longitude in
                    viewModel.addCustomLocation(name: name, lat: latitude, lon: longitude)
                    showingAddLocationSheet = false
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search for cities", text: $searchText)
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
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(.top, 60)
            
            Text("No Saved Locations")
                .font(.headline)
            
            Text("Save your favorite locations to quickly access weather information")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                viewModel.saveCurrentLocation()
            } label: {
                Label("Add Current Location", systemImage: "location")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            
            Button {
                showingAddLocationSheet = true
            } label: {
                Label("Add Custom Location", systemImage: "plus")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var savedLocationsList: some View {
        List {
            // Current location section
            Section(header: Text("CURRENT LOCATION")) {
                Button {
                    viewModel.requestCurrentLocation()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("Current Location")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Saved locations section
            Section(header: Text("SAVED LOCATIONS")) {
                ForEach(viewModel.locationManager.savedLocations) { location in
                    Button {
                        viewModel.useSavedLocation(location)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(location.name)
                                
                                if viewModel.hasCachedData(for: location.name) {
                                    Text("Cached data available")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.removeSavedLocation(id: location.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var searchResults: some View {
        VStack {
            if searchText.count < 2 {
                Text("Enter at least 2 characters to search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
            } else {
                Button {
                    viewModel.searchLocation(query: searchText)
                    dismiss()
                } label: {
                    HStack {
                        Text("Search for \"\(searchText)\"")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "magnifyingglass")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding()
            }
        }
    }
}

struct AddLocationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var locationName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var onLocationAdded: (String, Double, Double) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Location Name", text: $locationName)
                    
                    TextField("Latitude (e.g. 37.7749)", text: $latitude)
                        .keyboardType(.decimalPad)
                    
                    TextField("Longitude (e.g. -122.4194)", text: $longitude)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button(action: validateAndAddLocation) {
                        Text("Add Location")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(isValid ? .blue : .gray)
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Invalid Input"),
                    message: Text(errorMessage ?? "Please check your input values"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var isValid: Bool {
        return !locationName.isEmpty && !latitude.isEmpty && !longitude.isEmpty
    }
    
    private func validateAndAddLocation() {
        guard let lat = Double(latitude) else {
            errorMessage = "Latitude must be a valid number"
            showingError = true
            return
        }
        
        guard let lon = Double(longitude) else {
            errorMessage = "Longitude must be a valid number"
            showingError = true
            return
        }
        
        guard lat >= -90 && lat <= 90 else {
            errorMessage = "Latitude must be between -90 and 90"
            showingError = true
            return
        }
        
        guard lon >= -180 && lon <= 180 else {
            errorMessage = "Longitude must be between -180 and 180"
            showingError = true
            return
        }
        
        onLocationAdded(locationName, lat, lon)
    }
}

struct SavedLocationsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = WeatherViewModel()
        return SavedLocationsView()
            .environmentObject(viewModel)
    }
}
