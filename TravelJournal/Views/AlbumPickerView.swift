import SwiftUI
import Photos
import SwiftData

// MARK: - Album Picker View

struct AlbumPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trip: Trip

    @State private var albums: [PHAssetCollection] = []
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var isLoading = true
    @State private var searchText = ""

    // Albums filtered by the search field (case-insensitive title match).
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
                    albumListView
                case .denied, .restricted:
                    permissionDeniedView
                case .notDetermined:
                    ProgressView("Requesting access...")
                @unknown default:
                    ProgressView("Requesting access...")
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
        .task {
            await requestPhotoAccess()
        }
    }

    private var albumListView: some View {
        Group {
            if isLoading {
                ProgressView("Loading albums...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredAlbums.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Albums Found" : "No Results",
                    systemImage: "photo.on.rectangle",
                    description: Text(
                        searchText.isEmpty
                            ? "No photo albums were found in your library."
                            : "No albums match \"\(searchText)\"."
                    )
                )
            } else {
                List(filteredAlbums, id: \.localIdentifier) { album in
                    AlbumPickerRowView(album: album) {
                        assignAlbum(album)
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
            Text("Please allow access to your photos in Settings to import albums.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func requestPhotoAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
            if status == .authorized || status == .limited {
                loadAlbums()
            }
        }
    }

    private func loadAlbums() {
        isLoading = true
        var result: [PHAssetCollection] = []

        // Mirror exactly what Photos.app shows in "My Albums":
        // fetchTopLevelUserCollections returns only the collections in the
        // user's album hierarchy — it excludes iPhoto sync events, hidden
        // collections, and other auto-generated entries that a raw
        // fetchAssetCollections call returns.
        // fetchTopLevelUserCollections is the same query Photos.app uses for
        // "My Albums" — it includes user albums, folders, and shared albums.
        let topLevel = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        result += Self.collectAlbums(from: topLevel)

        result.sort { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
        albums = result
        isLoading = false
    }

    /// Recursively collects asset collections from a PHCollection fetch result.
    /// Descends into any folder (the date-named clutter isn't nested inside a
    /// folder on every library — it sits at the top level as individual
    /// albums). The real filter is each album's own assetCollectionSubtype:
    /// only .albumRegular (created in Photos/iOS) and .albumCloudShared
    /// (shared albums) match what Photos.app lists under "My Albums" /
    /// "Shared Albums". iPhoto-imported date albums come through as
    /// .albumSyncedEvent or .albumImported and are excluded.
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
                let sub = PHCollection.fetchCollections(in: folder, options: nil)
                result += collectAlbums(from: sub)
            }
        }
        return result
    }

    private func assignAlbum(_ collection: PHAssetCollection) {
        guard !trip.albums.contains(where: { $0.appleAlbumId == collection.localIdentifier }) else {
            dismiss()
            return
        }
        for existing in trip.albums {
            modelContext.delete(existing)
        }
        let album = PhotoAlbum(appleAlbumId: collection.localIdentifier, metaData: nil)
        album.trip = trip
        modelContext.insert(album)
        dismiss()
    }
}

// MARK: - Album Picker Row

struct AlbumPickerRowView: View {
    let album: PHAssetCollection
    let onSelect: () -> Void

    @State private var thumbnail: UIImage? = nil
    @State private var photoCount: Int = 0

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(album.localizedTitle ?? "Untitled Album")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("\(photoCount) photos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .task {
            loadThumbnailAndCount()
        }
    }

    private func loadThumbnailAndCount() {
        let assets = PHAsset.fetchAssets(in: album, options: nil)
        photoCount = assets.count
        guard let firstAsset = assets.firstObject else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isSynchronous = false

        PHImageManager.default().requestImage(
            for: firstAsset,
            targetSize: CGSize(width: 112, height: 112),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async { thumbnail = image }
        }
    }
}
