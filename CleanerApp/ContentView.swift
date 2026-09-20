import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var viewModel = CleanupViewModel()
    @State private var showSettings = false
    @State private var showUpdateDialog = false

    var body: some View {
        Group {
            #if os(macOS)
            macBody
            #else
            iosBody
            #endif
        }
        .onAppear {
            viewModel.refreshDiskInfo()
            viewModel.refreshMemoryInfo()

            // Check for updates in background on launch
            Task {
                await UpdateService.shared.checkForUpdates(isUserInitiated: false)
                if case .updateAvailable = UpdateService.shared.state {
                    showUpdateDialog = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("checkForUpdates"))) { _ in
            showUpdateDialog = true
            Task {
                await UpdateService.shared.checkForUpdates(isUserInitiated: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("smartScan"))) { _ in
            guard !viewModel.isOperating else { return }
            viewModel.selectedTab = .smartCare
            Task { await viewModel.runSmartScan() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("scan"))) { _ in
            guard !viewModel.isOperating else { return }
            Task { await viewModel.scanAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("clean"))) { _ in
            viewModel.requestCleanSelected()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                diskInfo: viewModel.diskInfo,
                useTrash: $viewModel.useTrash,
                downloadAgeDaysThreshold: $viewModel.downloadAgeDaysThreshold,
                largeFileThresholdMB: $viewModel.largeFileThresholdMB,
                includeXcodeArchives: $viewModel.includeXcodeArchives
            )
        }
        .sheet(isPresented: $showUpdateDialog) {
            UpdateDialogView()
        }
        .alert("Confirm Clean", isPresented: $viewModel.showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task { await viewModel.confirmClean() }
            }
        } message: {
            Text(viewModel.confirmationMessage)
        }
    }

    // MARK: - macOS Navigation Split View

    #if os(macOS)
    private var macBody: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 320)
        } detail: {
            detailContent
                .frame(minWidth: 540, minHeight: 480)
        }
        .toolbar { toolbarContent }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedTab) {
            // Live System Mini Card
            Section {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Macintosh HD")
                                .font(.headline)
                            Text("\(viewModel.diskInfo.formattedFree) free of \(viewModel.diskInfo.formattedTotal)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(viewModel.diskInfo.usedPercentage * 100))%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(viewModel.diskInfo.usedPercentage > 0.85 ? .orange : .primary)
                    }

                    ProgressView(value: viewModel.diskInfo.usedPercentage)
                        .progressViewStyle(.linear)
                        .tint(viewModel.diskInfo.usedPercentage > 0.9 ? .red : viewModel.diskInfo.usedPercentage > 0.75 ? .orange : .blue)
                }
                .padding(.vertical, 4)
            } header: {
                Label("Status", systemImage: "internaldrive")
            }

            // Group tabs by Section Title
            ForEach(sidebarSections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.tabs) { tab in
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(colors: tab.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 24, height: 24)
                                Image(systemName: tab.iconName)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }

                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            // Badge for size if available
                            if let badge = tabBadge(for: tab) {
                                Text(badge)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 2)
                        .tag(tab)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .disabled(viewModel.isOperating)
    }

    private var sidebarSections: [(title: String, tabs: [NavigationTab])] {
        [
            ("SMART CARE", [.smartCare]),
            ("CLEANUP", [.systemJunk, .mailAttachments, .trashBins]),
            ("PROTECTION", [.malwareRemoval, .privacy]),
            ("SPEED", [.maintenance, .optimization]),
            ("APPLICATIONS", [.uninstaller, .appRemnants]),
            ("FILES", [.spaceLens, .largeAndOld, .duplicates])
        ]
    }

    private func tabBadge(for tab: NavigationTab) -> String? {
        switch tab {
        case .systemJunk:
            let size = (viewModel.scanResults[.systemCache]?.totalSize ?? 0) + (viewModel.scanResults[.tempFiles]?.totalSize ?? 0) + (viewModel.scanResults[.appLogs]?.totalSize ?? 0)
            return size > 0 ? viewModel.formatBytes(size) : nil
        case .mailAttachments:
            let size = viewModel.scanResults[.downloads]?.totalSize ?? 0
            return size > 0 ? viewModel.formatBytes(size) : nil
        case .malwareRemoval:
            let count = viewModel.scanResults[.malware]?.itemCount ?? 0
            return count > 0 ? "\(count) threats" : nil
        case .optimization:
            let broken = viewModel.brokenStartupItemsCount
            return broken > 0 ? "\(broken) broken" : nil
        case .uninstaller:
            return viewModel.installedApps.isEmpty ? nil : "\(viewModel.installedApps.count) apps"
        case .appRemnants:
            let size = viewModel.scanResults[.appRemnants]?.totalSize ?? 0
            return size > 0 ? viewModel.formatBytes(size) : nil
        case .largeAndOld:
            let size = viewModel.scanResults[.largeFiles]?.totalSize ?? 0
            return size > 0 ? viewModel.formatBytes(size) : nil
        case .duplicates:
            let size = viewModel.scanResults[.duplicateFiles]?.totalSize ?? 0
            return size > 0 ? viewModel.formatBytes(size) : nil
        default:
            return nil
        }
    }

    // MARK: - Detail Router

    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.selectedTab {
        case .smartCare:
            SmartCareView(viewModel: viewModel)
        case .uninstaller:
            AppUninstallerView(viewModel: viewModel)
        case .maintenance:
            MaintenanceView(viewModel: viewModel)
        case .optimization:
            OptimizationView(viewModel: viewModel)
        case .spaceLens:
            SpaceLensView(viewModel: viewModel)
        case .privacy:
            PrivacyModuleView(viewModel: viewModel)
        case .trashBins:
            TrashBinsView(viewModel: viewModel)
        case .systemJunk:
            categoryDetailView(for: .systemCache)
        case .mailAttachments:
            categoryDetailView(for: .downloads)
        case .malwareRemoval:
            categoryDetailView(for: .malware)
        case .appRemnants:
            categoryDetailView(for: .appRemnants)
        case .largeAndOld:
            categoryDetailView(for: .largeFiles)
        case .duplicates:
            categoryDetailView(for: .duplicateFiles)
        }
    }

    @ViewBuilder
    private func categoryDetailView(for category: CleanupCategory) -> some View {
        if case .scanning(let currentCat, let progress) = viewModel.phase {
            ScanProgressView(
                currentCategory: currentCat,
                progress: progress,
                onCancel: { viewModel.cancelOperation() }
            )
        } else if case .cleaning(let currentCat, let progress) = viewModel.phase {
            CleaningProgressView(
                progress: progress,
                category: currentCat,
                onCancel: { viewModel.cancelOperation() }
            )
        } else if case .complete = viewModel.phase {
            CompleteView(viewModel: viewModel)
        } else {
            CategoryFilesView(category: category, viewModel: viewModel)
        }
    }
    #endif

    // MARK: - iOS View

    #if os(iOS)
    private var iosBody: some View {
        NavigationStack {
            SmartCareView(viewModel: viewModel)
                .navigationTitle("MacPurge")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }
    #endif

    // MARK: - Toolbar

    #if os(macOS)
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.runSmartScan() }
                } label: {
                    Label("Smart Scan", systemImage: "sparkles")
                }
                .help("Run One-Click Smart Scan (⇧⌘S)")
                .disabled(viewModel.isOperating)

                Button {
                    Task { await viewModel.scanAll() }
                } label: {
                    Label("Scan All", systemImage: "arrow.clockwise")
                }
                .help("Scan All Categories (⌘R)")
                .disabled(viewModel.isOperating)

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .help("Preferences")

                if viewModel.selectedScannableSpace > 0 {
                    Button { viewModel.requestCleanSelected() } label: {
                        Label("Clean (\(viewModel.formatBytes(viewModel.selectedScannableSpace)))", systemImage: "trash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(viewModel.isOperating)
                }
            }
        }
    }
    #endif
}
