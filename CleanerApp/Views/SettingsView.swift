import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let diskInfo: AppState
    @Binding var useTrash: Bool
    @Binding var downloadAgeDaysThreshold: Int
    @Binding var largeFileThresholdMB: Int
    @Binding var includeXcodeArchives: Bool

    @State private var updater = UpdateService.shared
    @State private var showUpdateSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Disk Overview") {
                    LabeledContent("Total Capacity", value: diskInfo.formattedTotal)
                    LabeledContent("Used Space", value: diskInfo.formattedUsed)
                    LabeledContent("Free Space", value: diskInfo.formattedFree)
                }

                #if os(macOS)
                Section("Cleaning Safety") {
                    Toggle(isOn: $useTrash) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Move files to Trash")
                                .font(.body)
                            Text("Recommended. Lets you recover files if needed before permanently deleting.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #endif

                Section("Scan Rules & Filters") {
                    Picker("Downloads Cleanup Filter", selection: $downloadAgeDaysThreshold) {
                        Text("Older than 7 days").tag(7)
                        Text("Older than 14 days").tag(14)
                        Text("Older than 30 days (Default)").tag(30)
                        Text("Older than 60 days").tag(60)
                        Text("Older than 90 days").tag(90)
                        Text("All downloaded files").tag(0)
                    }

                    Picker("Large Files Threshold", selection: $largeFileThresholdMB) {
                        Text("Larger than 25 MB").tag(25)
                        Text("Larger than 50 MB").tag(50)
                        Text("Larger than 100 MB (Default)").tag(100)
                        Text("Larger than 250 MB").tag(250)
                        Text("Larger than 500 MB").tag(500)
                        Text("Larger than 1 GB").tag(1000)
                    }

                    #if os(macOS)
                    Toggle(isOn: $includeXcodeArchives) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include Xcode Archives")
                                .font(.body)
                            Text("Archives contain release binaries and dSYMs. Keep disabled to prevent deleting archived builds.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    #endif
                }

                Section("Software Updates") {
                    Toggle("Automatically check for updates", isOn: $updater.autoCheckUpdates)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MacPurge \(updater.currentVersion)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let last = updater.lastCheckDate {
                                Text("Last checked: \(last.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Check for Updates...") {
                            showUpdateSheet = true
                            Task {
                                await updater.checkForUpdates(isUserInitiated: true)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section("Privacy & Security") {
                    Label("MacPurge operates entirely locally on your Mac. No personal files, logs, or analytics are transmitted over the internet.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: updater.currentVersion)
                    LabeledContent("Platform", value: "macOS & iOS")
                    LabeledContent("Developer", value: "Daksh Raman")
                    LabeledContent("License", value: "MIT Open Source")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Preferences")
            .sheet(isPresented: $showUpdateSheet) {
                UpdateDialogView()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }
}
