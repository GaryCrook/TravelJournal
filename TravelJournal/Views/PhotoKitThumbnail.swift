import SwiftUI
import Photos

/// Loads and displays a PhotoKit image from an asset identifier.
///
/// Usage:
///   PhotoKitThumbnail(assetIdentifier: photo.assetIdentifier, size: 100)
///       .frame(width: 100, height: 100)
///       .clipped()
///
/// - `size` drives the pixel request (multiplied by display scale internally).
/// - Shows a grey placeholder while loading or if the asset is unavailable.
struct PhotoKitThumbnail: View {
    let assetIdentifier: String
    let size: CGFloat

    @State private var image: UIImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(id: assetIdentifier) {
            image = await loadImage()
        }
    }

    // MARK: - Private

    private func loadImage() async -> UIImage? {
        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        )
        guard let asset = assets.firstObject else { return nil }

        let pixelSize = size * displayScale
        let targetSize = CGSize(width: pixelSize, height: pixelSize)

        let options = PHImageRequestOptions()
        // .opportunistic gives the best available quality but fires the callback
        // twice (degraded preview first, full quality second). Guard `resumed`
        // so the continuation is only resumed once on the final non-degraded call.
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                // Wait for the final (non-degraded) callback before resuming.
                // If the asset is unavailable (image == nil, isDegraded == false),
                // resume with nil so the placeholder shows.
                guard !isDegraded, !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
