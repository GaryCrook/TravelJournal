# TravelJournal — Session Notes
Last updated: 2026-07-05

## What was fixed this session

### 3 build errors in `PhotoQualityScoringService.swift`

**Root cause 1 — Missing `Photo` model properties**
`PhotoQualityScoringService` referenced three properties that didn't exist on the SwiftData `Photo` model:

| Property | Added as |
|---|---|
| `qualityScore` | `var qualityScore: Double?` — nil = not yet scored |
| `isDuplicate` | `var isDuplicate: Bool = false` |
| `isIncluded` | `var isIncluded: Bool = true` — false = auto-excluded |

Fixed in: `TravelJournal/Models/TravelJournalModels.swift`

**Root cause 2 — UIImage not PromptRepresentable**
Bare `UIImage` can't be used directly inside a `Prompt { }` result builder.
Fix: wrap with `Attachment(image)` — the Foundation Models type that bridges UIImage/NSImage/CGImage/CVPixelBuffer/URL into the prompt builder (iOS 27 API).

**Root cause 3 — Deployment target below iOS 27**
`Attachment` and related inits are iOS 27-only. Fixed by:
- Marking `generateScore(image:)` as `@available(iOS 27, *)`
- Wrapping the call site in `if #available(iOS 27, *)`

Fixed in: `TravelJournal/Services/PhotoQualityScoringService.swift`

## Project state

Build: ✅ clean  
Pipeline order: import → cluster → caption → **score** → journal  
`PhotoQualityScoringService` is complete and wired up.

## Files in the project

```
TravelJournal/
  Models/
    TravelJournalModels.swift       — Trip, PhotoAlbum, Visit, Location, Photo, JournalEntry, PhotoAlbumPhoto
  Services/
    GPSClusteringService.swift
    JournalGenerationService.swift
    PhotoImportService.swift
    PhotoQualityScoringService.swift  ← fixed this session
  Views/
    AlbumPickerView.swift
    ContentView.swift
    CreateTripView.swift
    EditTripView.swift
    JournalEntryRowView.swift
    PhotoKitThumbnail.swift
    TripDetailView.swift
    TripJournalTab.swift
    TripListView.swift
    TripLocationsTab.swift
    TripOverviewTab.swift
    TripPhotosTab.swift
  TravelJournalApp.swift
```

## Possible next steps

- Wire `PhotoQualityScoringService` into the UI (e.g. a "Score Photos" button on `TripPhotosTab`)
- Show `isIncluded` / `qualityScore` per photo in `TripPhotosTab` with a toggle to override
- Implement `PhotoCaptioningService` (referenced in comments but not yet in the project)
- Review `GPSClusteringService` — does it populate `Visit.location` correctly for journal generation?
