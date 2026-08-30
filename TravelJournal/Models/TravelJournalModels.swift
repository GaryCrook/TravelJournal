import SwiftData
import Foundation
import CoreLocation

// MARK: - Trip

@Model
class Trip {
    var tripName: String
    var startDate: Date
    var endDate: Date
    var destination: String
    var purpose: String
    var participants: Int
    var participantNames: String = ""   // optional comma-separated names, e.g. "Gary, Caroline"
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \PhotoAlbum.trip)
    var albums: [PhotoAlbum] = []

    @Relationship(deleteRule: .cascade, inverse: \Visit.trip)
    var visits: [Visit] = []

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.trip)
    var journalEntries: [JournalEntry] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Photo.trip)
    var photos: [Photo] = []
    
    init(
        tripName: String,
        startDate: Date,
        endDate: Date,
        destination: String,
        purpose: String = "",
        participants: Int = 1,
        participantNames: String = "",
        notes: String = ""
    ) {
        self.tripName = tripName
        self.startDate = startDate
        self.endDate = endDate
        self.destination = destination
        self.purpose = purpose
        self.participants = participants
        self.participantNames = participantNames
        self.notes = notes
    }
}

// MARK: - PhotoAlbum

@Model
class PhotoAlbum {
    var appleAlbumId: String       // PHAssetCollection localIdentifier
    var metaData: Data?            // JSON stored as Data

    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Visit.album)
    var visit: Visit?

    @Relationship(deleteRule: .cascade, inverse: \PhotoAlbumPhoto.album)
    var albumPhotos: [PhotoAlbumPhoto] = []

    init(appleAlbumId: String, metaData: Data? = nil) {
        self.appleAlbumId = appleAlbumId
        self.metaData = metaData
    }
}

// MARK: - Visit

@Model
class Visit {
    var datetime: Date
    var reason: String
    var participants: Int
    var weather: String
    var notes: String

    var trip: Trip?
    var album: PhotoAlbum?
    var location: Location?

    @Relationship(deleteRule: .cascade, inverse: \Photo.visit)
    var photos: [Photo] = []

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.visit)
    var journalEntries: [JournalEntry] = []

    init(
        datetime: Date,
        reason: String = "",
        participants: Int = 1,
        weather: String = "",
        notes: String = ""
    ) {
        self.datetime = datetime
        self.reason = reason
        self.participants = participants
        self.weather = weather
        self.notes = notes
    }
}

// MARK: - Location

@Model
class Location {
    var name: String
    var type: String
    var locationDescription: String
    var city: String
    var country: String
    var latitude: Double
    var longitude: Double

    @Relationship(inverse: \Visit.location)
    var visits: [Visit] = []

    @Relationship(inverse: \Photo.location)
    var photos: [Photo] = []

    @Relationship(inverse: \JournalEntry.location)
    var journalEntries: [JournalEntry] = []

    // Convenience property for CoreLocation
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        name: String,
        type: String = "",
        locationDescription: String = "",
        city: String,
        country: String,
        latitude: Double,
        longitude: Double
    ) {
        self.name = name
        self.type = type
        self.locationDescription = locationDescription
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Photo

@Model
class Photo {
    var datetime: Date
    var quality: Int
    var duplicate: Bool
    var participant: Int
    var burstIdentifier: String?
    var metadata: Data?            // EXIF JSON stored as Data
    var location: Location?
    var visit: Visit?
    var assetIdentifier: String      // PHAsset localIdentifier
    var aiCaption: String?
    var sceneTags: [String] = []
    var trip: Trip?
    var aiCaptionLong: String?   // one-sentence description — used as journal generation context
    var qualityScore: Double?    // AI-assigned 0.0–1.0 quality score; nil = not yet scored
    var isDuplicate: Bool = false
    var isIncluded: Bool = true  // false = auto-excluded by scoring; Gary can override
    var isFavourite: Bool = false // manually starred by Gary
    var isCoverPhoto: Bool = false // used as the trip card cover image

    @Relationship(deleteRule: .cascade, inverse: \PhotoAlbumPhoto.photo)
    var albumPhotos: [PhotoAlbumPhoto] = []

    init(
        assetIdentifier: String,        // ← add this
        datetime: Date = .now,
        quality: Int = 0,
        duplicate: Bool = false,
        participant: Int = 0,
        burstIdentifier: String? = nil,
        metadata: Data? = nil
    ) {
        self.assetIdentifier = assetIdentifier   // ← and this
        self.datetime = datetime
        self.quality = quality
        self.duplicate = duplicate
        self.participant = participant
        self.burstIdentifier = burstIdentifier
        self.metadata = metadata
    }
}

// MARK: - JournalEntry

@Model
class JournalEntry {
    var entryDate: Date
    var notes: String

    var trip: Trip?
    var visit: Visit?
    var location: Location?

    init(entryDate: Date = .now, notes: String = "") {
        self.entryDate = entryDate
        self.notes = notes
    }
}

// MARK: - PhotoAlbumPhoto (Junction)

@Model
class PhotoAlbumPhoto {
    var album: PhotoAlbum?
    var photo: Photo?

    init(album: PhotoAlbum, photo: Photo) {
        self.album = album
        self.photo = photo
    }
}
