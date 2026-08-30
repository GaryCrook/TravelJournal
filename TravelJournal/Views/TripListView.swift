import SwiftUI
import SwiftData
import Photos

// MARK: - Trip List View

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    @State private var showingCreateTrip = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var selectedYear: Int? = nil
    @State private var showingFilters = false

    // Unique years from all trips, newest first
    private var years: [Int] {
        Array(Set(trips.map {
            Calendar.current.component(.year, from: $0.startDate)
        })).sorted(by: >)
    }

    private var filteredTrips: [Trip] {
        trips.filter { trip in
            let yearMatch = selectedYear.map {
                Calendar.current.component(.year, from: trip.startDate) == $0
            } ?? true
            let searchMatch = searchText.isEmpty ||
                trip.tripName.localizedCaseInsensitiveContains(searchText) ||
                trip.destination.localizedCaseInsensitiveContains(searchText)
            return yearMatch && searchMatch
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DS.Color.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        searchBar
                            .padding(.horizontal, DS.Spacing.screen)
                            .padding(.bottom, DS.Spacing.lg)
                        sectionLabel
                            .padding(.horizontal, DS.Spacing.screen)
                            .padding(.bottom, DS.Spacing.md)
                        if !years.isEmpty && showingFilters {
                            yearFilterRow
                                .padding(.bottom, DS.Spacing.lg)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        tripCardList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingCreateTrip) {
                CreateTripView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Hello, Gary")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.primary)
                Text("Welcome to Travel Journal")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondary)
            }
            Spacer()
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(DS.Color.surface)
                        .foregroundStyle(DS.Color.secondary)
                        .clipShape(Circle())
                }
                Button {
                    showingCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(DS.Color.surface)
                        .foregroundStyle(DS.Color.primary)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, DS.Spacing.screen)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Color.secondary)
                    .font(.system(size: 15))
                TextField("Search trips…", text: $searchText)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingFilters.toggle()
                    if !showingFilters { selectedYear = nil }
                }
            } label: {
                Image(systemName: showingFilters ? "slider.horizontal.3" : "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 50, height: 50)
                    .background(showingFilters ? DS.Color.primary : DS.Color.surface)
                    .foregroundStyle(showingFilters ? .white : DS.Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
            }
        }
    }

    // MARK: - Section label

    private var sectionLabel: some View {
        HStack {
            Text("Select your next trip")
                .font(DS.Font.title2)
                .foregroundStyle(DS.Color.primary)
            Spacer()
            Text("\(filteredTrips.count) trip\(filteredTrips.count == 1 ? "" : "s")")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    // MARK: - Year filter pills

    private var yearFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                DSFilterPill(label: "All", selected: selectedYear == nil) {
                    withAnimation { selectedYear = nil }
                }
                ForEach(years, id: \.self) { year in
                    DSFilterPill(label: "\(year)", selected: selectedYear == year) {
                        withAnimation { selectedYear = year }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screen)
        }
    }

    // MARK: - Trip cards

    @ViewBuilder
    private var tripCardList: some View {
        if filteredTrips.isEmpty {
            emptyState
        } else {
            VStack(spacing: DS.Spacing.md) {
                ForEach(filteredTrips) { trip in
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        TripCardView(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(trip)
                        } label: {
                            Label("Delete Trip", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screen)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(DS.Color.secondary)
            Text("No trips yet")
                .font(DS.Font.title2)
                .foregroundStyle(DS.Color.primary)
            Text("Tap + to create your first trip")
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.secondary)
            Button("Create Trip") { showingCreateTrip = true }
                .font(DS.Font.callout)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(DS.Color.primary)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

}

// MARK: - Trip Card View

struct TripCardView: View {
    let trip: Trip

    // Cover priority: manually chosen > first favourite > first included > any photo
    private var coverPhotoId: String? {
        if let cover = trip.photos.first(where: { $0.isCoverPhoto }) {
            return cover.assetIdentifier
        }
        if let fav = trip.photos.filter({ $0.isFavourite && $0.isIncluded })
                                .sorted({ $0.datetime < $1.datetime }).first {
            return fav.assetIdentifier
        }
        return trip.photos
            .filter { $0.isIncluded }
            .sorted { $0.datetime < $1.datetime }
            .first?.assetIdentifier
            ?? trip.photos.sorted { $0.datetime < $1.datetime }.first?.assetIdentifier
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Hero image ───────────────────────────────────────────────
            Group {
                if let id = coverPhotoId {
                    PhotoKitThumbnail(assetIdentifier: id, size: 500)
                        .scaledToFill()
                } else {
                    coverPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .clipped()

            // ── Dark gradient overlay ─────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    // Destination (small label)
                    Text(trip.destination.uppercased())
                        .font(DS.Font.label)
                        .foregroundStyle(.white.opacity(0.75))
                        .tracking(1)

                    // Trip name (large)
                    Text(trip.tripName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    // Bottom row: stats + "Open" pill
                    HStack(spacing: 0) {
                        HStack(spacing: 12) {
                            statBadge(icon: "photo.on.rectangle",
                                      value: "\(trip.photos.count)")
                            statBadge(icon: "book.pages",
                                      value: "\(trip.journalEntries.count)")
                        }
                        Spacer()
                        openPill
                    }
                }
                .padding(DS.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.80)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private var openPill: some View {
        HStack(spacing: 6) {
            Text("Open")
                .font(DS.Font.callout)
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(DS.Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(Capsule())
    }

    private func statBadge(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(value)
                .font(DS.Font.label)
        }
        .foregroundStyle(.white.opacity(0.8))
    }

    private var coverPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "3A5A8A"), Color(hex: "6A8EBF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "airplane")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - Trip Date Formatting

extension Trip {
    var dateRangeFormatted: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate, to: endDate)
    }
}

