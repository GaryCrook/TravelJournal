import SwiftUI
import SwiftData

struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss

    let trip: Trip

    // Local copies — only written back to the model on Save,
    // so Cancel leaves the trip unchanged.
    @State private var tripName: String
    @State private var destination: String
    @State private var purpose: String
    @State private var notes: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var participants: Int
    @State private var participantNames: String

    init(trip: Trip) {
        self.trip = trip
        _tripName    = State(initialValue: trip.tripName)
        _destination = State(initialValue: trip.destination)
        _purpose     = State(initialValue: trip.purpose)
        _notes       = State(initialValue: trip.notes)
        _startDate   = State(initialValue: trip.startDate)
        _endDate     = State(initialValue: trip.endDate)
        _participants = State(initialValue: trip.participants)
        _participantNames = State(initialValue: trip.participantNames)
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Basic Details
                Section("Trip Details") {
                    TextField("Trip name", text: $tripName)
                    TextField("Destination", text: $destination)
                    TextField("Purpose (optional)", text: $purpose)
                }

                // MARK: - Dates
                Section("Dates") {
                    DatePicker(
                        "Start date",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "End date",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                }

                // MARK: - Participants
                Section {
                    Stepper("^[\(participants) person](inflect: true)", value: $participants, in: 1...20)
                    TextField("Names, e.g. Gary, Caroline", text: $participantNames)
                } header: {
                    Text("Participants")
                } footer: {
                    Text("Names entered here may be used in AI-generated captions and journal entries.")
                }

                // MARK: - Notes
                Section("Notes (optional)") {
                    TextField("Add any notes about this trip", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !tripName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveChanges() {
        guard isValid else { return }
        trip.tripName    = tripName.trimmingCharacters(in: .whitespaces)
        trip.destination = destination.trimmingCharacters(in: .whitespaces)
        trip.purpose     = purpose.trimmingCharacters(in: .whitespaces)
        trip.notes       = notes.trimmingCharacters(in: .whitespaces)
        trip.startDate   = startDate
        trip.endDate     = endDate
        trip.participants = participants
        trip.participantNames = participantNames.trimmingCharacters(in: .whitespaces)
        dismiss()
    }
}
