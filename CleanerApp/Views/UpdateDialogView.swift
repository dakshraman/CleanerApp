import SwiftUI

struct UpdateDialogView: View {
    @Bindable var updater = UpdateService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("MacPurge Software Update")
                        .font(.headline)
                    Text("Current Version: \(updater.currentVersion) (Build \(updater.currentBuild))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            switch updater.state {
            case .idle, .checking:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Checking for updates...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)

            case .upToDate:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)

                    Text("You're Up to Date!")
                        .font(.headline)

                    Text("MacPurge \(updater.currentVersion) is currently the newest version available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)

            case .updateAvailable(let newVersion, let notes, let downloadURL):
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("A new version of MacPurge is available!")
                            .font(.headline)
                        Spacer()
                        Text("v\(newVersion)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1), in: .capsule)
                            .foregroundStyle(.blue)
                    }

                    Text("Release Notes:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8))

                    HStack {
                        Button("Later") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)

                        Spacer()

                        if let url = downloadURL {
                            Button {
                                Task { await updater.downloadAndInstallUpdate(from: url) }
                            } label: {
                                Label("Update Automatically", systemImage: "arrow.down.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .keyboardShortcut(.defaultAction)
                        } else {
                            Link("Download from GitHub", destination: URL(string: "https://github.com/dakshraman/MacPurge/releases")!)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }

            case .downloading(let progress):
                VStack(spacing: 14) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("Downloading & Preparing Update...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)

            case .readyToInstall:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    Text("Installing Update & Restarting MacPurge...")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 120)

            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Check Again") {
                        Task { await updater.checkForUpdates(isUserInitiated: true) }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }

            if updater.state == .upToDate || updater.state == .failed(message: "") {
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
