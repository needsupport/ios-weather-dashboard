import SwiftUI
import CoreLocation

struct LocationManagementView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @State private var showingAddLocationSheet = false
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar for adding new locations
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search for a city...", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: {
                        viewModel.searchLocation(query: searchText)
                        searchText = ""
                    }) {
                        Text("Search")
                            .foregroundColor(.blue)
                    }
                    .disabled(searchText.isEmpty)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                // Divider between search and location list
                Divider()
                    .padding(.vertical, 5)
                
                // Location list
                List {
                    // Current location option
                    Section(header: Text("Current Location")) {
                        Button(action: {
                            viewModel.requestCurrentLocation()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text("Use Current Location")
                                        .font(.headline)
                                    
                                    if let address = viewModel.locationManager.lastKnownAddress {
                                        Text(address)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let currentLocation = viewModel.locationManager.currentLocation {
                            Button(action: {
                                viewModel.saveCurrentLocation()
                            }) {
                                Label("Save Current Location", systemImage: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // Saved locations
                    Section(header: Text("Saved Locations")) {
                        ForEach(viewModel.locationManager.savedLocations) { location in
                            Button(action: {
                                viewModel.useSavedLocation(location)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(location.name)
                                            .font(.headline)
                                            
                                        Text("\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            // Delete locations
                            for index in indexSet {
                                let location = viewModel.locationManager.savedLocations[index]
                                viewModel.removeSavedLocation(id: location.id)
                            }
                        }
                        
                        // Add custom location button
                        Button(action: {
                            showingAddLocationSheet = true
                        }) {
                            Label("Add Custom Location", systemImage: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationBarTitle("Manage Locations", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
            .sheet(isPresented: $showingAddLocationSheet) {
                AddCustomLocationView(isPresented: $showingAddLocationSheet)
                    .environmentObject(viewModel)
            }
        }
    }
}

struct AddCustomLocationView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @Binding var isPresented: Bool
    
    @State private var locationName = ""
    @State private var latitudeString = ""
    @State private var longitudeString = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Location Name", text: $locationName)
                        .autocapitalization(.words)
                    
                    TextField("Latitude (e.g., 37.7749)", text: $latitudeString)
                        .keyboardType(.decimalPad)
                    
                    TextField("Longitude (e.g., -122.4194)", text: $longitudeString)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button(action: addLocation) {
                        Text("Add Location")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationBarTitle("Add Custom Location", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    isPresented = false
                }
            )
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Invalid Coordinates"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var isFormValid: Bool {
        !locationName.isEmpty && !latitudeString.isEmpty && !longitudeString.isEmpty
    }
    
    private func addLocation() {
        guard let latitude = Double(latitudeString),
              let longitude = Double(longitudeString) else {
            errorMessage = "Please enter valid numbers for latitude and longitude"
            showingError = true
            return
        }
        
        // Validate coordinates
        guard latitude >= -90 && latitude <= 90 else {
            errorMessage = "Latitude must be between -90 and 90"
            showingError = true
            return
        }
        
        guard longitude >= -180 && longitude <= 180 else {
            errorMessage = "Longitude must be between -180 and 180"
            showingError = true
            return
        }
        
        // Add the location
        viewModel.addCustomLocation(name: locationName, lat: latitude, lon: longitude)
        isPresented = false
    }
}

struct LocationManagementView_Previews: PreviewProvider {
    static var previews: some View {
        LocationManagementView()
            .environmentObject(WeatherViewModel())
    }
}
