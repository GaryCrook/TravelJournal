# TravelJournal — Project State
_Last updated: 2 August 2026_

## Build Status
⚠️ **Not yet rebuilt/run since the fixes below** — do a clean build first when
resuming (Trip model gained a new stored property; delete derived data if
SwiftData throws a migration error on first launch).
✅ Last confirmed build succeeded (iOS 27 / Xcode beta, iPad target, iPad Air
11-inch M4)

## Latest Session (2 Aug 2026) — bug-fix pass

1. **Album picker showed dozens of date-named albums instead of the real ~34.**
   Root cause: iPhoto-imported "event" albums come through as
   `PHAssetCollection` with `assetCollectionSubtype == .albumSyncedEvent` /
   `.albumImported`, not nested inside a folder as first assumed. Fixed by
   filtering on each album's own subtype (`.albumRegular` /
   `.albumCloudShared` only) in `AlbumPickerView.collectAlbums` and
   `CreateTripView.AlbumSelectorSheet.collectAlbums`. **Needs re-verification
   against the real device library** — confirm the ~34-album count and that
   no legitimate albums got excluded.

2. **Journal text leaked raw `tool_call: {...}` JSON before the prose.**
   The on-device Foundation Model was leaking a fake tool-call preamble on
   freeform `session.respond(to:)` calls. Fixed by switching
   `JournalGenerationService.generateText` to structured generation
   (`generating: JournalText.self`, a new `@Generable` wrapper), matching the
   pattern `PhotoCaptioningService` already used successfully.

3. **Photo captions invented names and unearned detail** (e.g. "Anna and
   Jón", "feeling the pulse of Iceland's ancient heartbeat"). Root cause:
   the captioning prompts said "write as if you know the people personally"
   with no grounding. Fixed:
   - Added `Trip.participantNames` (comma-separated, e.g. "Gary, Caroline") —
     new field on the trip form (Create + Edit), optional, defaults to `""`.
   - `PhotoCaptioningService` now merges Photos' own People/Pets face
     recognition with `Trip.participantNames` into a closed name list; the
     model may only use names from that list, never invent others. If the
     list is empty, no one is named.
   - Same "never invent a name" rule added to `JournalGenerationService`'s
     system prompt for consistency, since journal text is built from
     (now-fixed) photo captions.

4. **`+` button on the trip list didn't respond to taps.**
   `TripListView` used `.navigationBarHidden(true)`, which leaves a phantom
   nav bar intercepting touches at the top of the screen — exactly where the
   `+` sits above the search box. Replaced with
   `.toolbar(.hidden, for: .navigationBar)`.

5. **Swift concurrency warning** in `PhotoCaptioningService`: `'people'
   mutated after capture by sendable closure`. Fixed by building the merged
   name list into a scratch `var`, then binding the final result to an
   immutable `let people` before the `Task { }` closure captures it.

## What's Done

### Core Pipeline (all wired and working)
1. **PhotoImportService** — imports photos from a selected Photos album into SwiftData
2. **GPSClusteringService** — clusters photos by GPS into Location/Visit records; uses `MKReverseGeocodingRequest`; photos with no GPS silently skipped
3. **PhotoCaptioningService** — two modes (see AI Features below); 30s per-photo timeout
4. **PhotoQualityScoringService** — two modes (see AI Features below); 30s per-photo timeout
5. **JournalGenerationService** — writes journal entries from visit + photo context; 60s per-entry timeout

### AI Features — multimodal vision toggle
- `UserDefaults` key: `multimodalVisionEnabled` (default: false)
- Toggle in **Settings sheet** (gear icon in TripListView header)
- **Vision OFF** (default, stable): captions from metadata (people/location/date); scoring uses neutral default 0.75; all photos included
- **Vision ON** (beta, may hang): `Attachment(image)` sent to Foundation Models for visual captioning and quality scoring
- Timeouts on all vision calls prevent permanent hangs
- No rebuild needed to switch — takes effect on next pipeline run
- Re-enable once Foundation Models `Attachment` API is stable in a later iOS 27 beta

### Trip Creation Flow (updated)
- Album is selected **first** in `CreateTripView` via `AlbumSelectorSheet`
- Start/end dates **auto-fill** from earliest/latest photo `creationDate` in the album
- Dates remain editable; section header shows "Auto-filled from album"
- On Save: trip and album are created together in one step
- Opening the new trip in `TripDetailView` **auto-triggers the pipeline** (`.onAppear` fires if album present but no photos yet)
- Existing in-trip album change flow still works via `AlbumPickerView` + `.onChange`

### Views
- **TripListView** — DS redesign; gear icon (settings) + plus icon (new trip) in header
- **SettingsView** — new; Apple Intelligence Vision toggle with current-behaviour summary
- **TripDetailView** — TabView pipeline container; auto-triggers pipeline on appear for new trips
- **TripOverviewTab** — stat tiles + pipeline progress; DS-styled
- **TripPhotosTab** — 3-column grid, tap-to-detail
- **PhotoDetailView** — caption card, quality bar, include/exclude toggle, metadata
- **TripLocationsTab** — MapKit map (260pt) with tappable pins + location cards; scroll-to-card on pin tap
- **TripJournalTab** — journal entry cards; share button exports plain-text diary via iOS share sheet
- **AlbumPickerView** — used for in-trip album change; requires existing Trip
- **AlbumSelectorSheet** — used in CreateTripView; callback-based, no Trip needed
- **CreateTripView** — album-first flow with date auto-fill
- **PhotoKitThumbnail** — opportunistic delivery with isDegraded guard

### Design System (`DesignSystem.swift`)
- `enum DS` with `Color`, `Font`, `Radius`, `Spacing`, `Shadow`
- Font: Instrument Sans (UIFont nil-check fallback to SF Pro)
- Primary `#212529` / Surface `#f5f6f7` / Background `#ffffff`
- Reusable: `DSFilterPill`, `DSPrimaryButton`, `DSIconButton`

### Info.plist
- `NSPhotoLibraryUsageDescription` — required for PHPhotoLibrary access on device ✅

### project.pbxproj — membershipExceptions
Excludes from `PBXFileSystemSynchronizedRootGroup` auto-sync:
- `Info.plist`
- `InstrumentSans-Regular.ttf` (stray duplicate)
- `InstrumentSans-Medium.ttf` (stray duplicate)
- `InstrumentSans-SemiBold.ttf` (stray duplicate)
- `InstrumentSans-Bold.ttf` (stray duplicate)
- `Views/JournalEntryRowView.swift` (unused, excluded from compilation)

## Known Issues / Follow-up
- **Foundation Models `Attachment` vision** — hangs in current iOS 27 beta; disabled by default; re-test with each new beta using the Settings toggle
- **Country field in Location** — `MKAddress` has no structured country property; `country = ""`
- **4 stray .ttf files** in `TravelJournal/TravelJournal/` root — excluded from build; delete via Finder when convenient
- **`JournalEntryRowView.swift`** — excluded from compilation; delete from Finder when convenient
- **Not yet re-tested since this session's fixes** — see "Next Steps" below

## File Map
```
TravelJournal/
├── Instrument_Sans/static/          ← font source files
├── TravelJournal.xcodeproj/
└── TravelJournal/
    ├── DesignSystem.swift
    ├── TravelJournalApp.swift
    ├── Info.plist                    ← NSPhotoLibraryUsageDescription added
    ├── Models/
    │   └── TravelJournalModels.swift ← Trip now has participantNames: String = ""
    ├── Services/
    │   ├── PhotoImportService.swift
    │   ├── GPSClusteringService.swift
    │   ├── PhotoCaptioningService.swift  ← vision/metadata toggle; 30s timeout; closed name list (Photos face IDs + Trip.participantNames), never invents
    │   ├── PhotoQualityScoringService.swift ← vision/default toggle; 30s timeout
    │   └── JournalGenerationService.swift   ← 60s timeout; structured generation (JournalText) — no more tool_call leak
    └── Views/
        ├── ContentView.swift
        ├── TripListView.swift        ← gear icon for settings; + button fixed (toolbar(.hidden) not navigationBarHidden)
        ├── SettingsView.swift        ← NEW: multimodal vision toggle
        ├── TripDetailView.swift      ← onAppear pipeline trigger for new trips
        ├── TripOverviewTab.swift
        ├── TripPhotosTab.swift
        ├── PhotoDetailView.swift
        ├── TripLocationsTab.swift    ← MapKit map + pins
        ├── TripJournalTab.swift      ← share sheet export
        ├── PhotoKitThumbnail.swift
        ├── AlbumPickerView.swift     ← in-trip album change; collectAlbums filters by assetCollectionSubtype (.albumRegular/.albumCloudShared)
        ├── CreateTripView.swift      ← album-first + date auto-fill + AlbumSelectorSheet (same subtype filter); participant names field
        ├── EditTripView.swift        ← participant names field
        └── JournalEntryRowView.swift ← excluded from build, can delete
```

## Next Steps (when resuming)
1. **Clean build first** — Trip model gained `participantNames`; watch for a
   SwiftData migration error on first launch (delete derived data / reinstall
   the app on device if it crashes on launch).
2. Confirm the `+` button on the trip list now opens New Trip.
3. Create a trip, enter participant names (e.g. "Gary, Caroline"), pick an
   album, and confirm the album picker shows the real ~34 albums (not the
   date-named iPhoto Events clutter).
4. Run the pipeline and check photo captions and journal text: names should
   only appear if they were entered as participants or identified by Photos'
   People/Pets — never invented. No `tool_call:` JSON should appear in
   journal text.
5. Test metadata-only captions (vision OFF) — are they useful?
6. When a new iOS 27 beta drops, toggle vision ON in Settings and test Attachment stability
7. Consider adding a "Re-run pipeline" button to TripOverviewTab for trips that already have photos
8. Delete stray .ttf files and JournalEntryRowView.swift via Finder

## New Feedback — Not Yet Started (2 Aug 2026, evening)

Gary reviewed the journal output and flagged six issues. None of these are
started — logging here so the next session can pick them up directly.

1. **Journal text isn't selectable/copyable.**
   `TripJournalTab.MagazineEntrySection` renders `entry.notes` as a plain
   `Text` view. Add `.textSelection(.enabled)` (and likely to the photo
   captions too) so the text can be selected and copied.

2. **Photos and text run full width — need margins.**
   `MagazineLeadPhoto` and `MagazinePhotoGrid` currently bleed edge-to-edge
   (`frame(maxWidth: .infinity)` with no horizontal padding). The journal
   text already has `DS.Spacing.screen` padding, but Gary wants photos
   constrained to the same margin so nothing is full-bleed — review both in
   `TripJournalTab.swift`.

3. **Weather is too verbose/robotic and ignores time of day.**
   Currently reads like "light snow, 3–6°C, 10.6mm rain" — a full-day
   range/aggregate. Gary wants a concise, natural phrase for the actual
   conditions **at the time the photos were taken** (morning/afternoon/
   evening), not a whole-day summary. Likely needs `WeatherService` to pull
   Open-Meteo **hourly** data and pick the hour nearest the visit's
   timestamp, then format naturally (e.g. "cold and overcast, around 4°C")
   rather than dumping min/max + precipitation numbers.

4. **Journal prose should be first person, not third person by name.**
   Participants (from the new `Trip.participantNames` field) can be named
   once near the start, then the entry should continue in first person
   ("I"/"we") rather than repeating "Gary and Caroline" throughout. Update
   `JournalGenerationService`'s system/user prompt — this likely needs
   trip-level state (has this trip's journal already introduced the
   participants?) similar to the existing `weatherMentionedOnDay` tracking,
   so names appear once per trip (or once per day), not every entry.

5. **Journal text is still inventing actions, not just names.**
   Example: "Gary and Caroline walked ___" was written but never happened —
   fabricated. The existing "don't invent facts" rule in
   `JournalGenerationService`'s system prompt isn't catching invented verbs/
   actions, only invented names/sensory detail. Needs a stronger, explicit
   rule: only describe actions/events stated in the photo captions — if a
   caption doesn't say someone did something, the journal entry can't say it
   either.

6. **No description of the place — needed when a new place is visited.**
   `Location.locationDescription` exists on the model but is never
   populated — `GPSClusteringService` only sets `name`/`city`/`country`.
   Gary wants a short description generated the first time a new location
   appears in a trip (e.g. via reverse-geocode POI data or a short LLM
   summary) and surfaced in the journal (`TripJournalTab` section header)
   and/or `TripLocationsTab` location cards.
