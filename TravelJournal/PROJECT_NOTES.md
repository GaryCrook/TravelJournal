# Travel Journal — Project Notes

## Status: Active development
Last updated: 2026-08-16

---

## Architecture

- **SwiftUI + SwiftData**, targeting iOS 27
- **FoundationModels** (on-device Apple Intelligence) for captioning, scoring, and journal generation
- **Photos framework** (PHKit) for album access and asset loading

### Key files
| File | Purpose |
|------|---------|
| `Models/TravelJournalModels.swift` | All SwiftData models |
| `DesignSystem.swift` | Colours, typography, spacing, reusable components |
| `Views/TripListView.swift` | Home screen; includes `TripCardView` and `Trip.dateRangeFormatted` extension |
| `Views/TripDetailView.swift` | Tab container for a single trip; owns the full AI pipeline |
| `Views/TripOverviewTab.swift` | Pipeline progress, album assignment, stat tiles |
| `Views/TripPhotosTab.swift` | Photo grid; badges for cover/favourite/excluded |
| `Views/PhotoDetailView.swift` | Full photo detail; include/exclude, favourite, cover photo toggles |
| `Views/TripLocationsTab.swift` | Map + location cards |
| `Views/TripJournalTab.swift` | Magazine-style journal; share button |
| `Views/AlbumPickerView.swift` | Album picker for in-trip album change |
| `Views/CreateTripView.swift` | New trip form; includes `AlbumSelectorSheet` |
| `Views/EditTripView.swift` | Edit trip metadata |
| `Views/SettingsView.swift` | Toggle for Apple Intelligence Vision mode |
| `Services/PhotoImportService.swift` | Imports PHAssets → Photo records |
| `Services/GPSClusteringService.swift` | Clusters photos by location → Location + Visit |
| `Services/WeatherService.swift` | Fetches historical weather from Open-Meteo |
| `Services/PhotoCaptioningService.swift` | AI short + long captions (vision or metadata) |
| `Services/PhotoQualityScoringService.swift` | AI quality score 0–1; auto-excludes poor shots |
| `Services/JournalGenerationService.swift` | AI journal prose per location/day group |

---

## AI Pipeline (runs automatically after album is assigned)

1. **PhotoImportService** — fetch all images from the album into `Photo` records
2. **GPSClusteringService** — greedy temporal-spatial clustering → `Location` + `Visit`
3. **WeatherService** — Open-Meteo archive API per visit (skips visits already set)
4. **PhotoCaptioningService** — short + long AI captions per photo
5. **PhotoQualityScoringService** — score 0–1; auto-exclude score < 0.4 or duplicates
6. **JournalGenerationService** — prose entry per (location, calendar day) group

Pipeline is triggered from `TripDetailView.triggerPipeline()`. Safe to re-run — each step skips already-processed records.

---

## Vision mode toggle

`UserDefaults` key `"multimodalVisionEnabled"` (set in Settings).
- **ON**: sends photo image to on-device model via `Attachment(image)` — may hang on early iOS 27 betas
- **OFF**: metadata-only captioning; neutral quality score (0.75); all photos included by default

---

## Photo model fields (Photo)

| Field | Type | Notes |
|-------|------|-------|
| `assetIdentifier` | String | PHAsset localIdentifier |
| `datetime` | Date | |
| `qualityScore` | Double? | nil = not yet scored |
| `isDuplicate` | Bool | flagged by AI |
| `isIncluded` | Bool | false = excluded from journal |
| `isFavourite` | Bool | manually starred by Gary |
| `isCoverPhoto` | Bool | shown on trip card; only one per trip |
| `aiCaption` | String? | short caption (≤8 words) |
| `aiCaptionLong` | String? | 20–45 word sentence for journal context |

**Cover photo priority** (TripCardView): `isCoverPhoto` → first favourite → first included → any photo

---

## Completed work (sessions to date)

### Session 1–3 (earlier)
- Full data model designed and built
- All five services implemented
- TripDetailView, TripOverviewTab, TripPhotosTab, TripLocationsTab, TripJournalTab
- AlbumPickerView, CreateTripView, EditTripView, SettingsView
- Build stabilised; duplicate view declarations resolved

### Session 4 (2026-08-16)
**Bugs fixed**
- `LanguageModelSession { "string" }` result builder error — fixed in JournalGenerationService and PhotoCaptioningService (2 instances); same fix already applied to PhotoQualityScoringService
- `loadImage` continuation safety — added `isDegraded`/`resumed` guard in PhotoQualityScoringService to prevent double-resume crash with `.opportunistic` delivery mode
- `PhotoCaptioningService` silent failure on iOS 26 — added `else` branch with metadata-only fallback; changed `generateCaptionFromMetadata` from `@available(iOS 27, *)` → `@available(iOS 26, *)`

**Outstanding items resolved**
- Filter button in TripListView was non-functional `Image` — now a real `Button` that toggles year filter pills with animation
- Swipe-to-delete was dead code — replaced with long-press context menu delete on trip cards
- Removed dead `deleteTrips(at:)` function and unused `TripStatView`
- Removed redundant `NavigationStack` from `TripPhotosTab` (only tab that had one)
- Country field in GPSClusteringService was always empty — now extracted from last line of formatted address

**New features**
- Photo favouriting (`isFavourite`) and cover photo selection (`isCoverPhoto`) added to Photo model
- PhotoDetailView: "Photo Options" card with favourite ★ toggle and "Use as trip cover" toggle (setting cover clears it from all other photos in the trip)
- TripPhotosTab grid: ★ badge on favourites, portrait icon on cover photo, eye-slash on excluded
- TripCardView: cover priority logic (manual cover → favourite → included → any)

---

## App Store submission (session 5 — 2026-08-29)

### Icon
All three icon variants (AppIcon.png, AppIcon-Dark.png, AppIcon-Tinted.png) updated with a navy badge and bold "AI" label in the bottom-right corner.

### Submission documents (all in `AppStore/` folder)
| File | Contents |
|------|----------|
| `metadata.md` | App name, subtitle, description, keywords, What's New, review notes |
| `InfoPlist-additions.md` | NSPhotoLibraryUsageDescription string + Xcode steps; notes on what NOT to add |
| `privacy-policy.html` | Hosted privacy policy ready to publish at your support URL |
| `PrivacyInfo.xcprivacy` | Privacy manifest (repo root); must be added to Xcode target |

### Checklist before TestFlight submission
- [ ] Add `NSPhotoLibraryUsageDescription` to Info.plist (see InfoPlist-additions.md)
- [ ] Add `PrivacyInfo.xcprivacy` to Xcode project target (File → Add Files)
- [ ] Host `privacy-policy.html` at `https://gcrook.github.io/traveljournal-ai/privacy`
- [ ] Create App Store Connect record: name "Travel Journal AI", category Travel, 4+, Free
- [ ] Paste description/keywords/subtitle from metadata.md into App Store Connect
- [ ] Take screenshots on iPhone 16 Pro (6.3") and iPad Pro (13") — required sizes
- [ ] Archive and upload from Xcode → Organizer → Distribute App → TestFlight

### Screenshot guidance
Apple requires at least 6.3" iPhone screenshots (mandatory). 12.9" iPad screenshots unlock iPad distribution.
Use the iOS Simulator or a physical device. Recommended screens to capture:
1. Trip list (home screen with a trip card)
2. Trip overview tab (pipeline complete, stats visible)
3. Photo grid (with favourite/cover badges)
4. Locations map tab
5. Journal tab (readable entry text)
6. Photo detail (caption + options card)

---

## Known limitations / next candidates

- `country` extraction from `MKAddressRepresentations.formatted` is a best-effort last-line parse — may be inaccurate for some locales
- `Trip.dateRangeFormatted` extension is defined in `TripListView.swift` — could move to `TravelJournalModels.swift`
- Vision mode may hang on early iOS 27 betas (noted in SettingsView footer)
- Open-Meteo archive API has ~1–2 day lag; very recent trips may get no weather
