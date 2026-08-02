import Foundation
import SwiftData
import Photos
import UIKit
import FoundationModels

// PhotoQualityScoringService
//
// Scores each photo in a trip for quality.
//
// Two modes controlled by UserDefaults key "multimodalVisionEnabled":
//
//   Vision ON  — sends the photo to the on-device Foundation Model via
//                Attachment(image) and returns a structured quality score.
//                May hang in early iOS 27 betas.
//
//   Vision OFF — assigns a neutral default score (0.75). All photos are
//                included by default; Gary can exclude individually in
//                PhotoDetailView.
//
// Toggle in Settings → Apple Intelligence Vision (no rebuild needed).

@Observable
class PhotoQualityScoringService {

    var isRunning = false
    var status = ""
    var progress = 0
    var total = 0

    // MARK: - Structured output

    @Generable
    struct PhotoScore {
        @Guide(description: """
            A quality score from 0.0 to 1.0 for this travel photo.
            Score 0.9–1.0: sharp, well-exposed, interesting subject or composition.
            Score 0.7–0.8: good quality with minor flaws (slight blur, busy background).
            Score 0.5–0.6: mediocre — noticeably blurry, poorly exposed, or cluttered.
            Score 0.3–0.4: poor — significantly blurry, very dark, or mostly obscured.
            Score 0.0–0.2: unusable — completely out of focus, accidental, or black frame.
            """)
        var score: Double

        @Guide(description: """
            True if this photo appears to be a near-duplicate — for example a burst shot
            taken within seconds of others with almost identical framing.
            False otherwise.
            """)
        var isDuplicate: Bool
    }

    private let exclusionThreshold: Double = 0.4
    private let defaultScore: Double = 0.75

    // MARK: - Public entry point

    @MainActor
    func scorePhotos(for trip: Trip, context: ModelContext) async {
        guard !isRunning else { return }

        let useVision = UserDefaults.standard.bool(forKey: "multimodalVisionEnabled")

        let unscored = trip.photos.filter { $0.qualityScore == nil }
        guard !unscored.isEmpty else {
            status = "All photos already scored."
            return
        }

        isRunning = true
        total = unscored.count
        progress = 0
        status = "Scoring \(total) photo\(total == 1 ? "" : "s")…"

        if useVision, #available(iOS 27, *) {
            // Check Apple Intelligence availability before attempting vision
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                switch model.availability {
                case .unavailable(let reason):
                    status = unavailableMessage(for: reason)
                default:
                    status = "Apple Intelligence is not available on this device."
                }
                isRunning = false
                return
            }
            await scoreWithVision(unscored, context: context)
        } else {
            scoreWithDefaults(unscored, context: context)
        }
    }

    // MARK: - Vision scoring

    @available(iOS 27, *)
    private func scoreWithVision(_ photos: [Photo], context: ModelContext) async {
        for photo in photos {
            progress += 1
            status = "Scoring photo \(progress) of \(total)…"

            guard let image = await loadImage(assetIdentifier: photo.assetIdentifier) else {
                photo.qualityScore = 0.0
                photo.isDuplicate = false
                photo.isIncluded = false
                continue
            }

            let scoreTask = Task { await generateScore(image: image) }
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(30))
                scoreTask.cancel()
            }
            if let result = await scoreTask.value {
                photo.qualityScore = result.score
                photo.isDuplicate = result.isDuplicate
                if result.score < exclusionThreshold || result.isDuplicate {
                    photo.isIncluded = false
                }
            } else {
                photo.qualityScore = defaultScore
                photo.isDuplicate = false
            }
            timeoutTask.cancel()
        }

        try? context.save()
        let excluded = photos.filter { !($0.isIncluded) }.count
        status = "\(total) photo\(total == 1 ? "" : "s") scored. \(excluded) excluded."
        isRunning = false
    }

    // MARK: - Default scoring

    private func scoreWithDefaults(_ photos: [Photo], context: ModelContext) {
        for photo in photos {
            progress += 1
            status = "Scoring photo \(progress) of \(total)…"
            photo.qualityScore = defaultScore
            photo.isDuplicate = false
            // isIncluded stays true by default
        }
        try? context.save()
        status = "\(total) photo\(total == 1 ? "" : "s") scored."
        isRunning = false
    }

    // MARK: - Image loading

    private func loadImage(assetIdentifier: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            guard let asset = PHAsset.fetchAssets(
                withLocalIdentifiers: [assetIdentifier], options: nil
            ).firstObject else {
                continuation.resume(returning: nil)
                return
            }

            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 768, height: 768),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Score generation

    @available(iOS 27, *)
    private func generateScore(image: UIImage) async -> PhotoScore? {
        let session = LanguageModelSession {
            """
            You are a travel photo quality assessor. Evaluate photos on:
            - Sharpness and focus
            - Exposure (not too dark, not blown out)
            - Composition and subject clarity
            - Whether the photo adds value as a travel memory
            Be strict — most snapshots score between 0.4 and 0.8.
            Reserve 0.9–1.0 for genuinely excellent photos.
            """
        }

        do {
            let response = try await session.respond(
                to: Prompt {
                    Attachment(image)
                    "Assess the quality of this travel photo and flag if it looks like a burst or near-duplicate shot."
                },
                generating: PhotoScore.self
            )
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func unavailableMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Photo scoring requires an Apple Intelligence–capable device."
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in Settings to score photos."
        default:
            return "Apple Intelligence is not available right now."
        }
    }
}
