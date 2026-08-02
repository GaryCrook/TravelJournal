import SwiftUI
import SwiftData

@main
struct TravelJournalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Trip.self, PhotoAlbum.self, Visit.self,
                               Location.self, Photo.self, JournalEntry.self,
                               PhotoAlbumPhoto.self])
    }
}
