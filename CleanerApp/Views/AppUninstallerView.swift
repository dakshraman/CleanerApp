import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AppUninstallerView: View {
    @Bindable var viewModel: CleanupViewModel
    @State private var searchText = ""
    @State private var selectedAppForDetail: InstalledAppInfo?

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if viewModel.isScanningApps {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Scanning Installed Applications & Associated Files...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                ContentUnavailableView {
                    Label("No Applications Found", systemImage: "xmark.bin")
                } description: {
                    Text(searchText.isEmpty ? "Click Scan to discover installed applications and their full disk footprints." : "No applications matching '\(searchText)'")
                } actions: {
                    Button("Scan Applications", systemImage: "arrow.clockwise") {
                        Task { await viewModel.scanInstalledApps() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                appsList
            }

            Divider()
            footerBar
        }
        .navigationTitle("Uninstaller")
        .onAppear {
            if viewModel.installedApps.isEmpty {
                Task { await viewModel.scanInstalledApps() }
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("App Uninstaller")
                    .font(.headline)
                Text("\(viewModel.installedApps.count) applications found • Total \(viewModel.formatBytes(totalAppsSize))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8))
            .frame(maxWidth: 200)

            Button {
                Task { await viewModel.scanInstalledApps() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh Applications")
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var appsList: some View {
        List {
            ForEach(filteredApps) { app in
                let isSelected = viewModel.selectedAppIDs.contains(app.id)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.toggleAppSelection(app)
                        } label: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? .blue : .secondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)

                        #if os(macOS)
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                        #else
                        Image(systemName: "app.fill")
                            .font(.title2)
                            .foregroundStyle(.pink)
                            .frame(width: 32, height: 32)
                        #endif

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(app.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("v\(app.version)")
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(0.05), in: .capsule)
                                    .foregroundStyle(.secondary)
                            }

                            Text(app.bundleID)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(app.formattedTotalSize)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()

                            if app.supportingFilesSize > 0 {
                                Text("+ \(viewModel.formatBytes(app.supportingFilesSize)) support data")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Button {
                            if selectedAppForDetail?.id == app.id {
                                selectedAppForDetail = nil
                            } else {
                                selectedAppForDetail = app
                            }
                        } label: {
                            Image(systemName: selectedAppForDetail?.id == app.id ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Expanded detail showing supporting folders
                    if selectedAppForDetail?.id == app.id {
                        VStack(alignment: .leading, spacing: 4) {
                            Divider().padding(.vertical, 2)
                            Text("Associated Supporting Files (\(app.relatedURLs.count + 1) items):")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 6) {
                                Image(systemName: "app")
                                    .foregroundStyle(.pink)
                                Text("App Binary: \(app.appURL.path)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(viewModel.formatBytes(app.appBundleSize))
                                    .font(.caption2)
                                    .monospacedDigit()
                            }

                            ForEach(app.relatedURLs, id: \.self) { url in
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.blue)
                                    Text(url.path)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.leading, 40)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
                .contextMenu {
                    #if os(macOS)
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
                    }
                    Button("Open App") {
                        NSWorkspace.shared.open(app.appURL)
                    }
                    Divider()
                    #endif
                    Button("Uninstall '\(app.name)'", role: .destructive) {
                        Task { await viewModel.uninstallSingleApp(app) }
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }

    private var footerBar: some View {
        let selectedCount = viewModel.selectedAppIDs.count
        let selectedAppsSize = viewModel.installedApps
            .filter { viewModel.selectedAppIDs.contains($0.id) }
            .reduce(Int64(0)) { $0 + $1.totalSize }

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedCount) of \(viewModel.installedApps.count) apps selected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Will free: \(viewModel.formatBytes(selectedAppsSize))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                Task { await viewModel.uninstallSelectedApps() }
            } label: {
                Label("Complete Uninstall (\(viewModel.formatBytes(selectedAppsSize)))", systemImage: "trash.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedCount == 0 || viewModel.isOperating)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty {
            return viewModel.installedApps
        }
        return viewModel.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalAppsSize: Int64 {
        viewModel.installedApps.reduce(Int64(0)) { $0 + $1.totalSize }
    }
}
