import SwiftUI
import SwiftData
import Photos

struct CreateTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tripName = ""
    @State private var destination = ""
    @State private var purpose = ""
    @State private var notes = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var participants = 1
    @State private var participantNames = ""
    @State private var showingValidationError = false
    @State private var showingAlbumPicker = false
    @State private var selectedAlbum: PHAssetCollection?
    @State private var datesAutoFilled = false

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Album (first step)
                Section("Photo Album") {
                    Button {
                        showingAlbumPicker = true
                    } label: {
                        HStack {
                            Label(
                                selectedAlbum?.localizedTitle ?? "Choose Album",
                                systemImage: "photo.on.rectangle"
                            )
                            .foregroundStyle(selectedAlbum != nil ? DS.Color.primary : .secondary)
                            Spacer()
                            if selectedAlbum != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Color.primary)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                // MARK: - Basic Details
                Section("Trip Details") {
                    TextField("Trip name", text: $tripName)
                    TextField("Destination", text: $destination)
                    TextField("Purpose (optional)", text: $purpose)
                }

                // MARK: - Dates
                Section {
                    DatePicker(
                        "Start date",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "End date",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                } header: {
                    HStack {
                        Text("Dates")
                        if datesAutoFilled {
                            Spacer()
                            Text("Auto-filled from album")
                                .font(.caption2)
                                .foregroundStyle(DS.Color.secondary)
                                .textCase(nil)
                        }
                    }
                }

                // MARK: - Participants
                Section {
                    Stepper("^[\(participants) person](inflect: true)", value: $participants, in: 1...20)
                    TextField("Names, e.g. Gary, Caroline", text: $participantNames)
                } header: {
                    Text("Participants")
                } footer: {
                    Text("Names entered here may be used in AI-generated captions and journal entries.")
                }

                // MARK: - Notes
                Section("Notes (optional)") {
                    TextField("Add any notes about this trip", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTrip() }
                        .disabled(!isValid)
                }
            }
            .alert("Missing Details", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a trip name and destination.")
            }
            .sheet(isPresented: $showingAlbumPicker) {
                AlbumSelectorSheet { album in
                    selectedAlbum = album
                    applyDateRange(from: album)
                }
            }
        }
    }

    // MARK: - Date range from album

    private func applyDateRange(from collection: PHAssetCollection) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(in: collection, options: options)
        guard let first = assets.firstObject?.creationDate,
              let last = assets.lastObject?.creationDate else { return }
        startDate = Calendar.current.startOfDay(for: first)
        endDate = Calendar.current.startOfDay(for: last)
        datesAutoFilled = true
    }

    // MARK: - Validation

    private var isValid: Bool {
        !tripName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Save

    private func saveTrip() {
        guard isValid else {
            showingValidationError = true
            return
        }

        let trip = Trip(
            tripName: tripName.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate,
            destination: destination.trimmingCharacters(in: .whitespaces),
            purpose: purpose.trimmingCharacters(in: .whitespaces),
            participants: participants,
            participantNames: participantNames.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(trip)

        if let collection = selectedAlbum {
            let album = PhotoAlbum(appleAlbumId: collection.localIdentifier, metaData: nil)
            album.trip = trip
            modelContext.insert(album)
        }

        dismiss()
    }
}

// MARK: - Album Selector Sheet

/// Lightweight album picker used during trip creation.
/// Uses a callback instead of requiring an existing Trip.
struct AlbumSelectorSheet: View {
    let onSelect: (PHAssetCollection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var albums: [PHAssetCollection] = []
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var isLoading = true
    @State private var searchText = ""

    private var filteredAlbums: [PHAssetCollection] {
        guard !searchText.isEmpty else { return albums }
        return albums.filter {
            ($0.localizedTitle ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch authorizationStatus {
                case .authorized, .limited:
                    albumList
                case .denied, .restricted:
                    permissionDeniedView
                default:
                    ProgressView("Requesting access…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Select Album")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search albums")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await requestAccess() }
    }

    private var albumList: some View {
        Group {
            if isLoading {
                ProgressView("Loading albums…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredAlbums.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Albums Found" : "No Results",
                    systemImage: "photo.on.rectangle",
                    description: Text(searchText.isEmpty
                        ? "No photo albums found in your library."
                        : "No albums match \"\(searchText)\".")
                )
            } else {
                List(filteredAlbums, id: \.localIdentifier) { album in
                    AlbumPickerRowView(album: album) {
                        onSelect(album)
                        dismiss()
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Photo Access Required", systemImage: "photo.slash")
        } description: {
            Text("Please allow photo access in Settings.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
            if status == .authorized || status == .limited { loadAlbums() }
        }
    }

    private func loadAlbums() {
        isLoading = true
        var result: [PHAssetCollection] = []

        // Use fetchTopLevelUserCollections to match exactly what Photos.app
        // shows — excludes iPhoto sync events and hidden auto-generated albums.
        let topLevel = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        result += Self.collectAlbums(from: topLevel)

        result.sort { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
        albums = result
        isLoading = false
    }

    private static func collectAlbums(from collections: PHFetchResult<PHCollection>) -> [PHAssetCollection] {
        var result: [PHAssetCollection] = []
        collections.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection {
                let subtype = album.assetCollectionSubtype
                guard subtype == .albumRegular || subtype == .albumCloudShared else { return }
                if PHAsset.fetchAssets(in: album, options: nil).count > 0 {
                    result.append(album)
                }
            } else if let folder = collection as? PHCollectionList {
                // The date-named clutter isn't reliably nested inside a
                // folder, so descend into all folders and filter by each
                // album's own subtype above instead.
                let sub = PHCollection.fetchCollections(in: folder, options: nil)
                result += collectAlbums(from: sub)
            }
        }
        return result
    }
}
