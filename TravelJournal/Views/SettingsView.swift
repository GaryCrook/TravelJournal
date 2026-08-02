import SwiftUI

struct SettingsView: View {
    @AppStorage("multimodalVisionEnabled") private var multimodalVisionEnabled = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Apple Intelligence Vision", isOn: $multimodalVisionEnabled)
                } header: {
                    Text("AI Features (Beta)")
                } footer: {
                    Text(multimodalVisionEnabled
                         ? "Vision is ON. Photos are sent to the on-device model for visual captioning and quality scoring. Disable if the app hangs during photo processing."
                         : "Vision is OFF. Captions use location, date, and people from photo metadata. Quality scoring uses a neutral default. All photos are included by default.")
                }

                Section {
                    LabeledContent("Captioning", value: multimodalVisionEnabled ? "Visual (beta)" : "Metadata only")
                    LabeledContent("Quality scoring", value: multimodalVisionEnabled ? "Visual (beta)" : "Default score")
                } header: {
                    Text("Current behaviour")
                }

                Section {
                    Text("Apple Intelligence multimodal APIs (Attachment/vision) can hang in early iOS 27 betas. Toggle this off if processing stalls on captioning or scoring. Rebuilding the app is not required — the change takes effect on the next pipeline run.")
                        .font(DS.Font.label)
                        .foregroundStyle(DS.Color.secondary)
                } header: {
                    Text("About this setting")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
