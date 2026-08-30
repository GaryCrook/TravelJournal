import Foundation
import SwiftData
import Photos
import UIKit
import FoundationModels

// PhotoCaptioningService
//
// Generates AI captions for each photo.
//
// Two modes controlled by UserDefaults key "multimodalVisionEnabled":
//
//   Vision ON  — sends the photo image to the on-device Foundation Model
//                via Attachment(image). Produces visually-descriptive captions.
//                May hang in early iOS 27 betas.
//
//   Vision OFF — generates captions from metadata only (people, location, date).
//                Fast and reliable. Captions are personalised but not visual.
//
// Toggle in Settings → Apple Intelligence Vision (no rebuild needed).

@Observable
class PhotoCaptioningService {

    var isRunning = false
    var status = ""
    var progress = 0
    var total = 0

    // MARK: - Structured output

    @Generable
    struct PhotoCaption {
        @Guide(description: """
            A short caption for this travel photo, at most 8 words.
            If named people or pets are listed under "People/pets", you may use
            those names. Never use any other name — if no names are listed, do
            not name anyone; describe the scene generically instead.
            If a location is provided, you may reference it.
            Examples: "Gary and Harvey at the harbour", "Sunset over Torquay bay",
            "Street market stalls in Lisbon", "Mountain trail above the clouds".
            Do not start with "A" or "An". No punctuation at the end.
            """)
        var shortCaption: String

        @Guide(description: """
            A single descriptive sentence (20–45 words) that would read well in
            a travel journal. Use only the names, location, and date provided —
            never invent a name for a person or pet that isn't listed. If no
            names are listed, refer to people generically (e.g. "the group",
            "a local vendor") or omit them. Do not invent emotions, atmosphere,
            or sensory detail beyond what the provided context supports.
            Write in present tense, plain prose — no markdown.
            Example: "Gary and Harvey explore the harbour front at low tide,
            fishing boats lining the quay as gulls circle overhead."
            """)
        var longCaption: String
    }

    // MARK: - Public entry point

    @MainActor
    func captionPhotos(for trip: Trip, context: ModelContext) async {
        guard !isRunning else { return }

        let useVision = UserDefaults.standard.bool(forKey: "multimodalVisionEnabled")

        // Foundation Models availability check
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            switch model.availability {
            case .unavailable(let reason):
                status = unavailableMessage(for: reason)
            default:
                status = "Apple Intelligence is not available on this device."
            }
            return
        }

        let uncaptioned = trip.photos.filter { $0.aiCaption == nil }
        guard !uncaptioned.isEmpty else {
            status = "All photos already captioned."
            return
        }

        isRunning = true
        total = uncaptioned.count
        progress = 0
        status = "Captioning \(total) photo\(total == 1 ? "" : "s")…"

        // Build person-album cache once
        let personAlbumMap = buildPersonAlbumMap()

        // Recorded trip participants (typed in on the trip form) — the only
        // other source of names we trust besides Photos' own People/Pets
        // recognition. Never pass any name to the model that isn't from one
        // of these two sources.
        let recordedParticipants = trip.participantNames
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for photo in uncaptioned {
            progress += 1
            status = "Captioning photo \(progress) of \(total)…"

            guard let asset = PHAsset.fetchAssets(
                withLocalIdentifiers: [photo.assetIdentifier], options: nil
            ).firstObject else {
                photo.aiCaption = ""
                photo.aiCaptionLong = ""
                continue
            }

            // Gather metadata context. Prefer photo-specific identification
            // from Photos' People/Pets albums; fall back to (and merge with)
            // the recorded trip participants. This is still a closed set —
            // the model is never free to invent a name outside it.
            let facePeople = namedPeople(in: asset, map: personAlbumMap)
            var mergedNames: [String] = []
            for name in facePeople + recordedParticipants where !mergedNames.contains(name) {
                mergedNames.append(name)
            }
            // Bind to an immutable `let` before the Task closure below
            // captures it — a captured `var`, even one only mutated before
            // capture, trips Swift's Sendable closure diagnostic.
            let people = mergedNames
            let locationName: String? = {
                if let loc = photo.location {
                    return [loc.name, loc.city].filter { !$0.isEmpty }.joined(separator: ", ")
                }
                return nil
            }()
            let shotDate = photo.datetime

            if #available(iOS 27, *) {
                let captionTask = Task {
                    if useVision, let image = await self.loadImage(from: asset) {
                        return await self.generateCaptionWithVision(
                            image: image, people: people, location: locationName, date: shotDate)
                    } else {
                        return await self.generateCaptionFromMetadata(
                            people: people, location: locationName, date: shotDate)
                    }
                }
                // 30s timeout — vision can hang in early betas
                let timeoutTask = Task {
                    try? await Task.sleep(for: .seconds(30))
                    captionTask.cancel()
                }
                if let result = await captionTask.value {
                    photo.aiCaption = result.shortCaption
                    photo.aiCaptionLong = result.longCaption
                } else {
                    photo.aiCaption = ""
                    photo.aiCaptionLong = ""
                }
                timeoutTask.cancel()
            } else {
                // iOS 26: vision not available, fall back to metadata-only captioning.
                // generateCaptionFromMetadata only uses text generation (iOS 26+).
                if #available(iOS 26, *) {
                    if let result = await generateCaptionFromMetadata(
                        people: people, location: locationName, date: shotDate
                    ) {
                        photo.aiCaption = result.shortCaption
                        photo.aiCaptionLong = result.longCaption
                    } else {
                        photo.aiCaption = ""
                        photo.aiCaptionLong = ""
                    }
                } else {
                    photo.aiCaption = ""
                    photo.aiCaptionLong = ""
                }
            }
        }

        try? context.save()
        status = "\(total) photo\(total == 1 ? "" : "s") captioned."
        isRunning = false
    }

    // MARK: - Person album lookup

    private func buildPersonAlbumMap() -> [String: String] {
        var map: [String: String] = [:]
        let smartFolderLists = PHCollectionList.fetchCollectionLists(
            with: .smartFolder, subtype: .smartFolderFaces, options: nil
        )
        smartFolderLists.enumerateObjects { list, _, _ in
            let children = PHCollection.fetchCollections(in: list, options: nil)
            children.enumerateObjects { child, _, _ in
                if let name = child.localizedTitle, !name.isEmpty {
                    map[child.localIdentifier] = name
                }
            }
        }
        return map
    }

    private func namedPeople(in asset: PHAsset, map: [String: String]) -> [String] {
        guard !map.isEmpty else { return [] }
        var names: [String] = []
        for (collectionId, name) in map {
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [collectionId], options: nil
            )
            if let collection = collections.firstObject {
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                assets.enumerateObjects { a, _, stop in
                    if a.localIdentifier == asset.localIdentifier {
                        names.append(name)
                        stop.pointee = true
                    }
                }
            }
        }
        return names
    }

    // MARK: - Image loading

    private func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast

            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 768, height: 768),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded, !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Caption generation (vision)

    @available(iOS 27, *)
    private func generateCaptionWithVision(
        image: UIImage,
        people: [String],
        location: String?,
        date: Date
    ) async -> PhotoCaption? {
        var contextLines: [String] = []
        if !people.isEmpty {
            contextLines.append("People/pets identified: \(people.joined(separator: ", ")).")
        }
        if let location { contextLines.append("Location: \(location).") }
        contextLines.append("Taken: \(date.formatted(date: .long, time: .shortened)).")
        let contextBlock = contextLines.joined(separator: "\n")

        let systemPrompt = """
        You are a travel photo captioner writing for a personal travel journal.
        Describe only what is visually confirmed in the photo, plus the context
        below. Do not invent facts, atmosphere, or emotions that aren't evident.
        Naming rule: only use names listed under "People/pets identified" below.
        Never invent a name for anyone or anything in the photo. If the photo
        shows people not in that list, refer to them generically (e.g. "a local
        vendor", "fellow travelers") — do not guess who they are. If no names
        are listed, do not name anyone at all.
        Be specific and warm in tone, but strictly factual. Plain prose only —
        no markdown.
        \(contextBlock)
        """

        let session = LanguageModelSession(instructions: systemPrompt)

        let instruction = contextLines.isEmpty
            ? "Describe this travel photo with a short caption and a longer sentence."
            : "Using the context above, describe this travel photo with a short caption and a longer sentence."

        do {
            let response = try await session.respond(
                to: Prompt {
                    Attachment(image)
                    instruction
                },
                generating: PhotoCaption.self
            )
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Caption generation (metadata only)

    @available(iOS 26, *)
    private func generateCaptionFromMetadata(
        people: [String],
        location: String?,
        date: Date
    ) async -> PhotoCaption? {
        var contextParts: [String] = []
        if !people.isEmpty {
            contextParts.append("People/pets present: \(people.joined(separator: ", "))")
        }
        if let location { contextParts.append("Location: \(location)") }
        contextParts.append("Date: \(date.formatted(date: .long, time: .omitted))")
        let contextBlock = contextParts.joined(separator: ". ")

        let session = LanguageModelSession(instructions: """
            You are a travel photo captioner writing for a personal travel journal.
            Write only from the facts given below — do not invent details,
            atmosphere, or emotions that aren't stated.
            Naming rule: only use names from "People/pets present" if provided.
            Never invent a name. If no people are listed, do not mention people
            by name at all — describe the location and moment generically.
            Plain prose only — no markdown.
            """
        )

        let prompt = """
        Write a short caption and a longer sentence for a travel photo taken with these details:
        \(contextBlock).
        The short caption should be at most 8 words, using names only if listed above.
        The longer sentence should be 20–45 words, specific and grounded in the facts given —
        do not invent who is present or what they're feeling.
        """

        do {
            let response = try await session.respond(to: prompt, generating: PhotoCaption.self)
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func unavailableMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Photo captioning requires an Apple Intelligence–capable device."
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in Settings to caption photos."
        default:
            return "Apple Intelligence is not available right now."
        }
    }
}
