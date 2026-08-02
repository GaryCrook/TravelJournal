import SwiftUI

// JournalEntryRowView
//
// Displays a single JournalEntry as an expandable card.
// The header shows the date and location; the body shows the full AI-generated
// journal text. Entries start collapsed to keep the list scannable,
// but a single tap reveals the full prose.

struct JournalEntryRowView: View {
    let entry: JournalEntry

    @State private var isExpanded = false

    private var locationName: String {
        entry.location?.name ?? "Unknown location"
    }

    private var cityCountry: String {
        let parts = [entry.location?.city, entry.location?.country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    private var formattedDate: String {
        entry.entryDate.formatted(date: .long, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────────────────
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {

                    // Calendar icon with day number
                    VStack(spacing: 2) {
                        Text(entry.entryDate.formatted(.dateTime.month(.abbreviated)))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)

                        Text(entry.entryDate.formatted(.dateTime.day()))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .frame(width: 44)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(formattedDate)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text(locationName)
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)

                        if !cityCountry.isEmpty {
                            Text(cityCountry)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Preview text when collapsed
                        if !isExpanded && !entry.notes.isEmpty {
                            Text(entry.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding()
            }
            .buttonStyle(.plain)

            // ── Body — full journal text ──────────────────────────────────────
            if isExpanded {
                Divider()
                    .padding(.horizontal)

                if entry.notes.isEmpty {
                    Text("No journal text yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding()
                } else {
                    Text(entry.notes)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(5)
                        .padding()
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
