import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let diskInfo: AppState
    @Binding var useTrash: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("About Cleaner") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Platforms", value: "macOS, iOS")
                    LabeledContent("Framework", value: "SwiftUI")
                }

                Section("Disk Information") {
                    LabeledContent("Total", value: diskInfo.formattedTotal)
                    LabeledContent("Used", value: diskInfo.formattedUsed)
                    LabeledContent("Free", value: diskInfo.formattedFree)
                }

                #if os(macOS)
                Section("Cleaning Behavior") {
                    Toggle(isOn: $useTrash) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Move files to Trash")
                                .font(.body)
                            Text("Safer — lets you recover files if needed. Disable to permanently delete.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #endif

                Section("Privacy") {
                    Text("Cleaner only accesses files in cache, temp, and log directories. No personal documents are read or transmitted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Support") {
                    Link(destination: URL(string: "https://github.com/anomalyco/opencode")!) {
                        Label("Report Issue", systemImage: "bug")
                    }
                    Link(destination: URL(string: "https://github.com/anomalyco/opencode")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
