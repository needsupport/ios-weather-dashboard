import SwiftUI

struct SavedLocationsView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddLocation = false
    @State private var isEditMode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.locationManager.savedLocations.isEmpty {
                    emptyStateView
                } else {
                    savedLocationsList
                }
            }
            .navigationTitle("Saved Locations")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditMode ? "Done" : "Edit") {
                        withAnimation {
                            isEditMode.toggle()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddLocation = true
                    }) {
                        Label("Add Location", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Saved Locations")
                .font(.title2)
            
            Text("Add locations to quickly access weather information for places you care about.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingAddLocation = true
            }) {
                Label("Add Location", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .padding()
    }
    
    private var savedLocationsList: some View {
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
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if viewModel.locationManager.isLoadingLocation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(viewModel.locationManager.isLoadingLocation)
            }
            
            // Saved locations section
            Section(header: Text("SAVED LOCATIONS")) {
                ForEach(viewModel.locationManager.savedLocations) { location in
                    Button(action: {
                        if !isEditMode {
                            viewModel.useSavedLocation(location)
                            dismiss()
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(location.name)
                                    .foregroundColor(.primary)
                                
                                if isEditMode {
                                    Text("\(location.latitude), \(location.longitude)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if isEditMode {
                                Button(action: {
                                    viewModel.removeSavedLocation(id: location.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isEditMode)
                }
                .onDelete(perform: deleteLocations)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            if index < viewModel.locationManager.savedLocations.count {
                let location = viewModel.locationManager.savedLocations[index]
                viewModel.removeSavedLocation(id: location.id)
            }
        }
    }
}

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: WeatherViewModel
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [SearchResult] = []
    @State private var showingCustomLocationInput = false
    @State private var customLocationName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    struct SearchResult: Identifiable {
        let id = UUID()
        let name: String
        let coordinates: (latitude: Double, longitude: Double)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText, isSearching: $isSearching, onCommit: performSearch)
                    .padding(.horizontal)
                
                if isSearching && searchResults.isEmpty {
                    searchingView
                } else if !searchResults.isEmpty {
                    searchResultsList
                } else {
                    contentView
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomLocationInput) {
                CustomLocationInputView(
                    locationName: $customLocationName,
                    latitude: $latitude,
                    longitude: $longitude,
                    onSave: {
                        addCustomLocation()
                    }
                )
            }
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 24) {
            Text("Search for a city or add coordinates")
                .font(.headline)
                .padding(.top, 20)
            
            Button(action: {
                viewModel.saveCurrentLocation()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.white)
                    Text("Save Current Location")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(viewModel.locationManager.currentLocation == nil)
            .opacity(viewModel.locationManager.currentLocation == nil ? 0.5 : 1.0)
            
            Button(action: {
                showingCustomLocationInput = true
            }) {
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.white)
                    Text("Enter Coordinates")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var searchingView: some View {
        VStack(spacing: 16) {
            if isSearching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.top, 40)
                
                Text("Searching for locations...")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
                
                Text("No locations found")
                    .font(.headline)
                
                Text("Try a different search term or add a custom location")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    showingCustomLocationInput = true
                }) {
                    Text("Add Custom Location")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
        }
        .padding()
    }
    
    private var searchResultsList: some View {
        List(searchResults) { result in
            Button(action: {
                addLocationFromSearch(result)
            }) {
                HStack {
                    Text(result.name)
                    Spacer()
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        // This would typically use a geocoding service
        // For now, just a mockup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.searchText.lowercased().contains("new york") {
                self.searchResults.append(
                    SearchResult(
                        name: "New York, NY, USA",
                        coordinates: (latitude: 40.7128, longitude: -74.0060)
                    )
                )
            } else if self.searchText.lowercased().contains("london") {
                self.searchResults.append(
                    SearchResult(
                        name: "London, UK",
                        coordinates: (latitude: 51.5074, longitude: -0.1278)
                    )
                )
            } else if self.searchText.lowercased().contains("paris") {
                self.searchResults.append(
                    SearchResult(
                        name: "Paris, France",
                        coordinates: (latitude: 48.8566, longitude: 2.3522)
                    )
                )
            }
            
            self.isSearching = false
        }
    }
    
    private func addLocationFromSearch(_ result: SearchResult) {
        viewModel.addCustomLocation(
            name: result.name,
            lat: result.coordinates.latitude,
            lon: result.coordinates.longitude
        )
        dismiss()
    }
    
    private func addCustomLocation() {
        guard !customLocationName.isEmpty,
              let lat = Double(latitude),
              let lon = Double(longitude) else {
            errorMessage = "Please enter valid location details"
            showingError = true
            return
        }
        
        viewModel.addCustomLocation(
            name: customLocationName,
            lat: lat,
            lon: lon
        )
        dismiss()
    }
}

struct CustomLocationInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var locationName: String
    @Binding var latitude: String
    @Binding var longitude: String
    var onSave: () -> Void
    
    var formIsValid: Bool {
        !locationName.isEmpty && 
        !latitude.isEmpty && 
        !longitude.isEmpty &&
        Double(latitude) != nil &&
        Double(longitude) != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Location Name", text: $locationName)
                        .autocapitalization(.words)
                    
                    TextField("Latitude (-90 to 90)", text: $latitude)
                        .keyboardType(.decimalPad)
                    
                    TextField("Longitude (-180 to 180)", text: $longitude)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button(action: {
                        onSave()
                        dismiss()
                    }) {
                        Text("Save Location")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(formIsValid ? .blue : .gray)
                    }
                    .disabled(!formIsValid)
                }
            }
            .navigationTitle("Custom Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    var onCommit: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search for a city", text: $text, onCommit: onCommit)
                    .disableAutocorrection(true)
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct SavedLocationsView_Previews: PreviewProvider {
    static var previews: some View {
        SavedLocationsView()
            .environmentObject(WeatherViewModel())
    }
}
