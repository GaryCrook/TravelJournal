import Foundation
import SwiftData
import FoundationModels

// JournalGenerationService
//
// Groups a trip's photos by (location, calendar day) and creates a
// JournalEntry for each unique combination. The entry's notes field is
// populated by the on-device Foundation Models language model.
//
// Safe to re-run: groups that already have a JournalEntry are skipped.
//
// Trigger: called automatically after GPS clustering completes.

@Observable
class JournalGenerationService {

    var isRunning = false
    var status = ""

    // MARK: - Structured output
    //
    // Using structured generation (generating: JournalText.self) rather than
    // freeform session.respond(to:) avoids a leak seen with the on-device
    // model: given a prompt with several "Label: value" lines, it sometimes
    // prefixes its reply with a fake `tool_call: {...}` JSON block before the
    // actual prose, even though no tools are registered. Structured output
    // constrains the model to the declared field and the leak disappears.
    @Generable
    struct JournalText {
        @Guide(description: """
            The journal entry prose only. Plain text — no JSON, no tool calls,
            no code fences, no markdown, no labels or field names.
            """)
        var text: String
    }

    // Moved to class scope so both generateJournalEntries and generateText can use it.
    private struct EntryGroup {
        let location: Location
        let visit: Visit
        let date: Date       // start of calendar day
        var photoCount: Int
    }

    // MARK: - Public entry point

    @MainActor
    func generateJournalEntries(for trip: Trip, context: ModelContext) async {
        guard !isRunning else { return }

        // ── Availability check ───────────────────────────────────────────────
        // Foundation Models require an Apple Intelligence–capable device with
        // the feature enabled. Degrade gracefully if unavailable.
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

        isRunning = true
        status = "Preparing journal entries…"

        // ── Group photos by (location, calendar day) ─────────────────────────
        // Each unique (location + day) combination becomes one JournalEntry.
        // Photos with no location assigned are skipped.

        let calendar = Calendar.current
        var groups: [String: EntryGroup] = [:]

        for visit in trip.visits {
            guard let location = visit.location else { continue }
            for photo in visit.photos {
                let day = calendar.startOfDay(for: photo.datetime)
                // Key combines location identity and day so each (place, date) is unique.
                let key = "\(ObjectIdentifier(location))-\(day.timeIntervalSince1970)"
                if var existing = groups[key] {
                    existing.photoCount += 1
                    groups[key] = existing
                } else {
                    groups[key] = EntryGroup(
                        location: location,
                        visit: visit,
                        date: day,
                        photoCount: 1
                    )
                }
            }
        }

        guard !groups.isEmpty else {
            status = "No photos with locations found."
            isRunning = false
            return
        }

        // ── Skip groups that already have a JournalEntry ─────────────────────
        let existingKeys = Set(
            trip.journalEntries.compactMap { entry -> String? in
                guard let loc = entry.location else { return nil }
                let day = calendar.startOfDay(for: entry.entryDate)
                return "\(ObjectIdentifier(loc))-\(day.timeIntervalSince1970)"
            }
        )

        let newGroups = groups
            .filter { !existingKeys.contains($0.key) }
            .sorted { $0.value.date < $1.value.date }

        guard !newGroups.isEmpty else {
            status = "Journal entries already up to date."
            isRunning = false
            return
        }

        let total = newGroups.count

        // Track which weather strings have already been mentioned per calendar day
        // so we don't repeat the same conditions across multiple location entries
        // in the same day.
        var weatherMentionedOnDay: [Date: String] = [:]

        // ── Generate one entry per group ─────────────────────────────────────
        for (index, (_, group)) in newGroups.enumerated() {
            status = "Writing entry \(index + 1) of \(total) — \(group.location.name)…"

            // Only include weather if it hasn't already appeared in an entry for
            // this calendar day. Same-day entries at different locations share
            // identical weather — no need to repeat it.
            let weather = group.visit.weather
            let alreadyMentioned = weatherMentionedOnDay[group.date] == weather && !weather.isEmpty
            let weatherForEntry = alreadyMentioned ? "" : weather
            if !weather.isEmpty { weatherMentionedOnDay[group.date] = weather }

            let genTask = Task { await generateText(for: group, weather: weatherForEntry) }
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(60))
                genTask.cancel()
            }
            let text = await genTask.value
            timeoutTask.cancel()

            let entry = JournalEntry(entryDate: group.date, notes: text)
            entry.trip = trip
            entry.visit = group.visit
            entry.location = group.location
            context.insert(entry)
        }

        try? context.save()
        status = "\(total) journal entr\(total == 1 ? "y" : "ies") created."
        isRunning = false
    }

    // MARK: - Private helpers

    /// Creates a fresh session per entry so entries are fully independent.
    /// `weather` is pre-filtered — pass empty string to suppress weather mention.
    private func generateText(for group: EntryGroup, weather: String) async -> String {
        let session = LanguageModelSession(instructions: """
            You write factual travel reports in a concise, first-person magazine style.
            Write ONLY from the facts provided. Do not invent sights, sounds, smells,
            atmosphere, or experiences that are not stated in the supplied information.
            Do not use phrases like "the air was filled with", "the sound of", or any
            sensory detail not confirmed by the photo descriptions.
            Never invent a person's name. Only use names that appear in the photo
            descriptions given to you — if none appear, don't refer to anyone by name.
            Plain prose only — no markdown, no headings, no bullet points, no JSON,
            no tool calls, no labels or field names of any kind.
            Keep to 2–3 sentences per paragraph, maximum 2 paragraphs.
            The section header already shows the date and location name, so do NOT
            open by restating them. Do not begin with "I visited", "On [date]", or
            "We arrived at". Start mid-experience — with what was seen, done, or noticed.
            """
        )

        let dateStr = group.date.formatted(date: .long, time: .omitted)
        let place = [group.location.name, group.location.city, group.location.country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        // Collect included photo captions as the factual source material.
        let captions = group.visit.photos
            .filter { $0.isIncluded && !($0.aiCaptionLong ?? "").isEmpty }
            .sorted { $0.datetime < $1.datetime }
            .compactMap { $0.aiCaptionLong }

        let captionBlock = captions.isEmpty
            ? "No photo descriptions available."
            : captions.enumerated().map { "Photo \($0.offset + 1): \($0.element)" }.joined(separator: "\n")

        let weatherLine = weather.isEmpty ? nil : "Weather: \(weather)"

        let prompt = """
        Write a factual travel report entry for this visit.

        Location: \(place)
        Date: \(dateStr)
        \(weatherLine.map { $0 + "\n" } ?? "")Photos taken: \(group.photoCount)

        Photo descriptions (use these as your only factual source for what was seen):
        \(captionBlock)

        Write only what the facts above confirm. \
        \(weather.isEmpty ? "" : "You may weave in the weather naturally — do not open with it. ")\
        If there are no photo descriptions, write one sentence describing when and where.
        Do not begin with "I visited", "On [date]", or any restatement of the location or date.
        """

        do {
            let response = try await session.respond(to: prompt, generating: JournalText.self)
            return response.content.text
        } catch {
            return "Visited \(place) on \(dateStr)."
        }
    }

    private func unavailableMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Journal generation requires an Apple Intelligence–capable device."
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in Settings to generate journal entries."
        default:
            return "Apple Intelligence is not available right now."
        }
    }
}
