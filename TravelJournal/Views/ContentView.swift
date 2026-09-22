import SwiftUI
import FoundationModels

struct ContentView: View {
    var body: some View {
        if #available(iOS 27, macCatalyst 27, *) {
            let availability = SystemLanguageModel.default.availability
            if case .unavailable(let reason) = availability,
               reason == .deviceNotEligible {
                AppleIntelligenceRequiredView()
            } else {
                TripListView()
            }
        } else {
            AppleIntelligenceRequiredView()
        }
    }
}

struct AppleIntelligenceRequiredView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Apple Intelligence Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Travel Journal AI uses on-device Apple Intelligence for photo captioning, quality scoring, and journal writing. This app requires an iPhone 15 Pro or later (or Mac with Apple Silicon).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}
