import SwiftUI
import SwiftData

// TripDetailView
//
// Top-level container for a single trip. Hosts the four tab views
// (Overview, Photos, Locations, Journal) and owns the full 5-step
// AI pipeline so services persist for the lifetime of the view.

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var trip: Trip

    @State private var showingEditTrip = false
    @State private var showingDeleteAlert = false
    @State private var showingAddAlbum = false
    @State private var showingRegenerateAlert = false

    // ── Pipeline services (shared across all tabs) ───────────────────────────
    @State private var importService    = PhotoImportService()
    @State private var clusteringService = GPSClusteringService()
    @State private var weatherService   = WeatherService()
    @State private var captioningService = PhotoCaptioningService()
    @State private var scoringService   = PhotoQualityScoringService()
    @State private var journalService   = JournalGenerationService()

    var body: some View {
        TabView {
            Tab("Overview", systemImage: "list.bullet") {
                TripOverviewTab(
                    trip: trip,
                    importService: importService,
                    clusteringService: clusteringService,
                    weatherService: weatherService,
                    captioningService: captioningService,
                    scoringService: scoringService,
                    journalService: journalService,
                    showingAddAlbum: $showingAddAlbum
                )
            }
            Tab("Photos", systemImage: "photo.on.rectangle") {
                TripPhotosTab(trip: trip)
            }
            Tab("Locations", systemImage: "mappin.and.ellipse") {
                TripLocationsTab(trip: trip)
            }
            Tab("Journal", systemImage: "book.pages") {
                TripJournalTab(trip: trip)
            }
        }
        .navigationTitle(trip.tripName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showingEditTrip = true } label: {
                        Label("Edit Trip", systemImage: "pencil")
                    }
                    Button { showingRegenerateAlert = true } label: {
                        Label("Regenerate Journal", systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteAlert = true } label: {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditTrip) {
            EditTripView(trip: trip)
        }
        .sheet(isPresented: $showingAddAlbum) {
            AlbumPickerView(trip: trip)
        }
        .onChange(of: showingAddAlbum) { _, isShowing in
            // Album added via the in-trip picker (album change flow)
            if !isShowing {
                triggerPipeline()
            }
        }
        .onAppear {
            // Album was assigned during trip creation — start pipeline automatically
            // if there is an album but no photos have been imported yet.
            if trip.photos.isEmpty, trip.albums.first != nil {
                triggerPipeline()
            }
        }
        .alert("Delete Trip", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteTrip() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(trip.tripName)\"? This cannot be undone.")
        }
        .alert("Regenerate Journal", isPresented: $showingRegenerateAlert) {
            Button("Regenerate", role: .destructive) { regenerateJournal() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all existing journal entries and rewrite them. Continue?")
        }
    }

    // MARK: - Pipeline

    private func triggerPipeline() {
        guard let album = trip.albums.first else { return }
        let albumId = album.appleAlbumId
        Task {
            await importService.importPhotos(from: albumId, into: trip, context: modelContext)
            await clusteringService.clusterPhotos(for: trip, context: modelContext)
            await weatherService.fetchWeather(for: trip, context: modelContext)
            await captioningService.captionPhotos(for: trip, context: modelContext)
            await scoringService.scorePhotos(for: trip, context: modelContext)
            await journalService.generateJournalEntries(for: trip, context: modelContext)
        }
    }

    // MARK: - Regenerate journal

    private func regenerateJournal() {
        for entry in trip.journalEntries {
            modelContext.delete(entry)
        }
        // Clear weather so it re-fetches with current location data
        for visit in trip.visits {
            visit.weather = ""
        }
        try? modelContext.save()
        Task {
            await weatherService.fetchWeather(for: trip, context: modelContext)
            await journalService.generateJournalEntries(for: trip, context: modelContext)
        }
    }

    // MARK: - Delete

    private func deleteTrip() {
        modelContext.delete(trip)
        dismiss()
    }
}
