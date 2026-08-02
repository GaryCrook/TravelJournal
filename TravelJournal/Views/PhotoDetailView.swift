import SwiftUI
import SwiftData

// PhotoDetailView
//
// Shown when the user taps a photo thumbnail in TripPhotosTab.
// Displays the full-size image alongside AI-generated metadata and
// lets Gary override the include/exclude decision made by scoring.

struct PhotoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var photo: Photo

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Full-size photo
                    PhotoKitThumbnail(assetIdentifier: photo.assetIdentifier, size: 800)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                        // MARK: - Caption
                        detailCard {
                            sectionLabel("Caption", systemImage: "text.bubble")
                            if let caption = photo.aiCaption, !caption.isEmpty {
                                Text(caption)
                                    .font(DS.Font.title2)
                                    .foregroundStyle(DS.Color.primary)
                                if let long = photo.aiCaptionLong, !long.isEmpty {
                                    Text(long)
                                        .font(DS.Font.body)
                                        .foregroundStyle(DS.Color.secondary)
                                        .lineSpacing(4)
                                }
                            } else {
                                Text("Not yet captioned")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }

                        // MARK: - Quality score
                        detailCard {
                            sectionLabel("Quality Score", systemImage: "star.circle")
                            if let score = photo.qualityScore {
                                HStack(spacing: 12) {
                                    QualityBar(score: score)
                                    Text(String(format: "%.0f%%", score * 100))
                                        .font(DS.Font.title2)
                                        .foregroundStyle(scoreColor(score))
                                        .monospacedDigit()
                                }
                                Text(scoreLabel(score))
                                    .font(DS.Font.label)
                                    .foregroundStyle(DS.Color.secondary)
                            } else {
                                Text("Not yet scored")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                            if photo.isDuplicate {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .foregroundStyle(.orange)
                                    Text("Flagged as likely duplicate or burst shot")
                                        .font(DS.Font.label)
                                        .foregroundStyle(DS.Color.secondary)
                                }
                            }
                        }

                        // MARK: - Include / exclude toggle
                        detailCard {
                            sectionLabel("Journal Inclusion", systemImage: "book.pages")
                            Toggle(isOn: $photo.isIncluded) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(photo.isIncluded ? "Included in journal" : "Excluded from journal")
                                        .font(DS.Font.callout)
                                        .foregroundStyle(DS.Color.primary)
                                    Text(photo.isIncluded
                                         ? "This photo will be used when writing journal entries."
                                         : "This photo is hidden from journal generation. Toggle to include it.")
                                        .font(DS.Font.label)
                                        .foregroundStyle(DS.Color.secondary)
                                }
                            }
                            .tint(DS.Color.primary)
                            .onChange(of: photo.isIncluded) { _, _ in
                                try? modelContext.save()
                            }
                        }

                        // MARK: - Metadata
                        detailCard {
                            sectionLabel("Details", systemImage: "info.circle")
                            metaRow("Date", value: photo.datetime.formatted(date: .long, time: .shortened))
                            if let location = photo.location {
                                metaRow("Location", value: [location.name, location.city]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: ", "))
                            }
                            if let visit = photo.visit {
                                metaRow("Visit", value: visit.location?.name ?? "Unknown")
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
            .background(DS.Color.surface.ignoresSafeArea())
            .navigationTitle(photo.aiCaption ?? "Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(DS.Font.callout)
                }
            }
        }
    }

    // MARK: - Card wrapper

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(DS.Color.background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(DS.Font.label)
            .fontWeight(.semibold)
            .foregroundStyle(DS.Color.secondary)
            .textCase(.uppercase)
    }

    private func metaRow(_ key: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.primary)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }

    private func scoreLabel(_ score: Double) -> String {
        switch score {
        case 0.9...: return "Excellent — likely a highlight shot"
        case 0.7..<0.9: return "Good quality with minor flaws"
        case 0.5..<0.7: return "Mediocre — worth reviewing"
        case 0.3..<0.5: return "Poor quality — auto-excluded"
        default: return "Unusable — auto-excluded"
        }
    }
}

// MARK: - Quality Bar

private struct QualityBar: View {
    let score: Double

    private var color: Color {
        switch score {
        case 0.8...: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * score)
            }
        }
        .frame(height: 8)
    }
}
