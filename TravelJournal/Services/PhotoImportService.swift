import Foundation
import Photos
import SwiftData

// PhotoImportService
// Fetches all images from a PHAssetCollection and creates Photo records in SwiftData.
// GPS coordinates are stored in photo.metadata as JSON for use later during clustering.

@Observable
class PhotoImportService {
    var isImporting = false
    var importedCount = 0
    var totalCount = 0

    var progress: Double {
        totalCount > 0 ? Double(importedCount) / Double(totalCount) : 0
    }

    // @MainActor is on the function (not the class) so @State initialisation works cleanly.
    // SwiftData and all property mutations stay on the main actor.
    @MainActor
    func importPhotos(
        from albumId: String,       // pass the localIdentifier, not the PHAssetCollection
        into trip: Trip,
        context: ModelContext
    ) async {
        guard !isImporting else { return }

        isImporting = true
        importedCount = 0
        totalCount = 0

        // ── Step 1: Fetch asset metadata on a background thread ──────────
        // We pass only a String (Sendable) into the detached task so Swift 6
        // strict concurrency is satisfied.
        let assetData = await Task.detached(priority: .userInitiated) {
            guard let collection = PHAssetCollection
                .fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
                .firstObject
            else { return [(id: String, date: Date, burstId: String?, lat: Double?, lng: Double?)]() }

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            options.predicate = NSPredicate(
                format: "mediaType == %d", PHAssetMediaType.image.rawValue
            )

            let assets = PHAsset.fetchAssets(in: collection, options: options)
            var result: [(id: String, date: Date, burstId: String?, lat: Double?, lng: Double?)] = []
            assets.enumerateObjects { asset, _, _ in
                result.append((
                    id: asset.localIdentifier,
                    date: asset.creationDate ?? .now,
                    burstId: asset.burstIdentifier,
                    lat: asset.location?.coordinate.latitude,
                    lng: asset.location?.coordinate.longitude
                ))
            }
            return result
        }.value

        totalCount = assetData.count
        guard totalCount > 0 else {
            isImporting = false
            return
        }

        // ── Step 2: Skip assets already imported for this trip ────────────
        let existingIds = Set(trip.photos.map { $0.assetIdentifier })

        // ── Step 3: Insert new Photo records ─────────────────────────────
        for (index, data) in assetData.enumerated() {
            if !existingIds.contains(data.id) {
                var metadataDict: [String: Any] = [:]
                if let lat = data.lat, let lng = data.lng {
                    metadataDict["latitude"] = lat
                    metadataDict["longitude"] = lng
                }

                let photo = Photo(
                    assetIdentifier: data.id,
                    datetime: data.date,
                    burstIdentifier: data.burstId,
                    metadata: try? JSONSerialization.data(withJSONObject: metadataDict)
                )
                photo.trip = trip
                context.insert(photo)
            }

            importedCount = index + 1

            if index % 20 == 0 {
                await Task.yield()
            }
        }

        try? context.save()
        isImporting = false
    }
}
