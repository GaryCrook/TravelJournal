import SwiftUI
import SwiftData

// TripOverviewTab
//
// Shows trip metadata, album assignment, pipeline progress, and summary
// stats. Pipeline services are owned by TripDetailView and passed in as
// references so their @Observable state drives this view's updates.

struct TripOverviewTab: View {
    let trip: Trip
    let importService: PhotoImportService
    let clusteringService: GPSClusteringService
    let weatherService: WeatherService
    let captioningService: PhotoCaptioningService
    let scoringService: PhotoQualityScoringService
    let journalService: JournalGenerationService
    @Binding var showingAddAlbum: Bool

    private var uniqueLocations: Int {
        Set(trip.visits.compactMap { $0.location }.map { ObjectIdentifier($0) }).count
    }

    private var tripDays: Int {
        Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                // ── Stat tiles ───────────────────────────────────────────────
                statTiles
                    .padding(.horizontal, DS.Spacing.screen)
                    .padding(.top, DS.Spacing.md)

                // ── Trip details ─────────────────────────────────────────────
                sectionCard(title: "Trip Details") {
                    detailRow(label: "Destination", value: trip.destination)
                    divider
                    detailRow(label: "Start", value: trip.startDate.formatted(date: .long, time: .omitted))
                    divider
                    detailRow(label: "End", value: trip.endDate.formatted(date: .long, time: .omitted))
                    divider
                    detailRow(label: "Duration", value: "\(tripDays) day\(tripDays == 1 ? "" : "s")")
                    if !trip.purpose.isEmpty {
                        divider
                        detailRow(label: "Purpose", value: trip.purpose)
                    }
                    divider
                    detailRow(label: "Participants", value: "\(trip.participants)")
                }

                // ── Photo Album ──────────────────────────────────────────────
                sectionCard(title: "Photo Album") {
                    if trip.albums.isEmpty {
                        Button {
                            showingAddAlbum = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.rectangle.on.folder")
                                    .font(.system(size: 20))
                                    .foregroundStyle(DS.Color.primary)
                                Text("Assign Photo Album")
                                    .font(DS.Font.callout)
                                    .foregroundStyle(DS.Color.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(trip.albums.count) album\(trip.albums.count == 1 ? "" : "s") linked")
                                .font(DS.Font.callout)
                                .foregroundStyle(DS.Color.primary)
                            Spacer()
                        }

                        // ── Pipeline progress ────────────────────────────────
                        if importService.isImporting {
                            divider
                            pipelineRow(
                                icon: "arrow.down.to.line",
                                message: "Importing photos…",
                                detail: "\(importService.importedCount) of \(importService.totalCount)",
                                progress: importService.progress
                            )
                        } else if clusteringService.isRunning {
                            divider
                            pipelineRow(icon: "mappin.and.ellipse", message: clusteringService.status)
                        } else if weatherService.isRunning {
                            divider
                            pipelineRow(icon: "cloud.sun", message: weatherService.status)
                        } else if captioningService.isRunning {
                            divider
                            pipelineRow(
                                icon: "text.bubble",
                                message: captioningService.status,
                                detail: captioningService.total > 0
                                    ? "\(captioningService.progress) of \(captioningService.total)" : nil,
                                progress: captioningService.total > 0
                                    ? Double(captioningService.progress) / Double(captioningService.total) : nil
                            )
                        } else if scoringService.isRunning {
                            divider
                            pipelineRow(
                                icon: "star.circle",
                                message: scoringService.status,
                                detail: scoringService.total > 0
                                    ? "\(scoringService.progress) of \(scoringService.total)" : nil,
                                progress: scoringService.total > 0
                                    ? Double(scoringService.progress) / Double(scoringService.total) : nil
                            )
                        } else if journalService.isRunning {
                            divider
                            pipelineRow(icon: "book.pages", message: journalService.status)
                        } else if !journalService.status.isEmpty {
                            divider
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(journalService.status)
                                    .font(DS.Font.callout)
                                    .foregroundStyle(DS.Color.primary)
                            }
                        }

                        divider
                        Button("Change Album") { showingAddAlbum = true }
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }

                // ── Notes ────────────────────────────────────────────────────
                if !trip.notes.isEmpty {
                    sectionCard(title: "Notes") {
                        Text(trip.notes)
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Color.surface.ignoresSafeArea())
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        HStack(spacing: DS.Spacing.md) {
            statTile(icon: "photo.on.rectangle", value: "\(trip.photos.count)", label: "Photos")
            statTile(icon: "mappin.circle", value: "\(uniqueLocations)", label: "Locations")
            statTile(icon: "book.pages", value: "\(trip.journalEntries.count)", label: "Entries")
            statTile(icon: "calendar", value: "\(tripDays)", label: "Days")
        }
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(DS.Color.primary)
            Text(value)
                .font(DS.Font.title2)
                .foregroundStyle(DS.Color.primary)
            Text(label)
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Color.background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Section card

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.secondary)
                .tracking(0.5)
                .textCase(.uppercase)
                .padding(.horizontal, DS.Spacing.screen)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                content()
            }
            .padding(DS.Spacing.md)
            .background(DS.Color.background)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            .padding(.horizontal, DS.Spacing.screen)
        }
    }

    // MARK: - Detail row

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.primary)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }

    private var divider: some View {
        Divider()
            .background(DS.Color.border)
    }

    // MARK: - Pipeline row

    @ViewBuilder
    private func pipelineRow(
        icon: String,
        message: String,
        detail: String? = nil,
        progress: Double? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Color.primary)
                Text(message)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.primary)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(DS.Font.label)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
            if let progress {
                ProgressView(value: progress)
                    .tint(DS.Color.primary)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(DS.Color.primary)
            }
        }
        .padding(.vertical, 4)
    }
}
