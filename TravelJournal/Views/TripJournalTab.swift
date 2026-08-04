import SwiftUI

// MARK: - TripJournalTab

struct TripJournalTab: View {
    let trip: Trip

    @State private var showingShareSheet = false

    private var sortedEntries: [JournalEntry] {
        trip.journalEntries.sorted { $0.entryDate < $1.entryDate }
    }

    var body: some View {
        Group {
            if sortedEntries.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        tripHero
                        ForEach(sortedEntries) { entry in
                            MagazineEntrySection(entry: entry)
                        }
                        Spacer(minLength: DS.Spacing.xl)
                    }
                }
                .background(DS.Color.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(DS.Color.primary)
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    ShareSheet(text: exportText)
                }
            }
        }
    }

    // MARK: - Trip hero

    private var tripHero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(trip.tripName)
                .font(DS.Font.display)
                .foregroundStyle(DS.Color.primary)
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "mappin")
                    .font(.system(size: 12))
                Text(trip.destination)
                    .font(DS.Font.callout)
            }
            .foregroundStyle(DS.Color.secondary)
            Text(trip.dateRangeFormatted)
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.secondary)
        }
        .padding(.horizontal, DS.Spacing.screen)
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xl)
    }

    // MARK: - Export text

    private var exportText: String {
        var lines: [String] = []
        lines.append(trip.tripName.uppercased())
        lines.append(trip.destination)
        lines.append(trip.dateRangeFormatted)
        lines.append(String(repeating: "─", count: 40))
        lines.append("")
        for entry in sortedEntries {
            lines.append(entry.entryDate.formatted(date: .complete, time: .omitted))
            if let loc = entry.location, !loc.name.isEmpty {
                lines.append("📍 \(loc.name)\(!loc.city.isEmpty ? ", \(loc.city)" : "")")
            }
            lines.append("")
            if !entry.notes.isEmpty { lines.append(entry.notes) }
            lines.append("")
            lines.append(String(repeating: "─", count: 40))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(DS.Color.secondary)
            Text("No Journal Entries Yet")
                .font(DS.Font.title2)
                .foregroundStyle(DS.Color.primary)
            Text("Journal entries are generated automatically from your visits and photos.")
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
        .background(DS.Color.surface.ignoresSafeArea())
    }
}

// MARK: - Magazine Entry Section

struct MagazineEntrySection: View {
    let entry: JournalEntry

    /// Photos for this entry, included only, chronological order.
    private var photos: [Photo] {
        (entry.visit?.photos ?? [])
            .filter { $0.isIncluded }
            .sorted { $0.datetime < $1.datetime }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Date + location header ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.entryDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.secondary)
                    .textCase(.uppercase)
                if let location = entry.location {
                    Text(location.name)
                        .font(DS.Font.title2)
                        .foregroundStyle(DS.Color.primary)
                    if !location.city.isEmpty {
                        Text(location.city)
                            .font(DS.Font.label)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screen)
            .padding(.bottom, DS.Spacing.md)

            // ── Lead photo (first, full width) ───────────────────────────────
            if let leadPhoto = photos.first {
                MagazineLeadPhoto(photo: leadPhoto)
                    .padding(.bottom, DS.Spacing.md)
            }

            // ── Journal text ─────────────────────────────────────────────────
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.primary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.screen)
                    .padding(.bottom, DS.Spacing.md)
            }

            // ── Remaining photos grid ────────────────────────────────────────
            let remaining = Array(photos.dropFirst())
            if !remaining.isEmpty {
                MagazinePhotoGrid(photos: remaining)
                    .padding(.bottom, DS.Spacing.md)
            }

            // ── Divider ──────────────────────────────────────────────────────
            Divider()
                .background(DS.Color.border)
                .padding(.horizontal, DS.Spacing.screen)
                .padding(.bottom, DS.Spacing.xl)
        }
    }
}

// MARK: - Lead Photo

struct MagazineLeadPhoto: View {
    let photo: Photo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhotoKitThumbnail(assetIdentifier: photo.assetIdentifier, size: 800)
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipped()

            if let caption = photo.aiCaption, !caption.isEmpty {
                Text(caption)
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.secondary)
                    .italic()
                    .padding(.horizontal, DS.Spacing.screen)
            }
        }
    }
}

// MARK: - Photo Grid

struct MagazinePhotoGrid: View {
    let photos: [Photo]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(photos) { photo in
                VStack(alignment: .leading, spacing: 4) {
                    PhotoKitThumbnail(assetIdentifier: photo.assetIdentifier, size: 400)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()

                    if let caption = photo.aiCaption, !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Color.secondary)
                            .italic()
                            .lineLimit(2)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
