import SwiftUI

struct ContentView: View {
    @State private var viewModel = CleanupViewModel()
    @State private var showSettings = false

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
            if case .idle = viewModel.phase {
                Task { await viewModel.scanAll() }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(diskInfo: viewModel.diskInfo, useTrash: $viewModel.useTrash)
        }
        .alert("Confirm Clean", isPresented: $viewModel.showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) { Task { await viewModel.confirmClean() } }
        } message: {
            Text(viewModel.confirmationMessage)
        }
    }

    // MARK: - macOS

    #if os(macOS)
    private var macBody: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
        } detail: {
            detailPanel
                .frame(minWidth: 420, minHeight: 400)
        }
        .toolbar { toolbarContent }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedCategory) {
            Section {
                LabeledContent("Free", value: viewModel.diskInfo.formattedFree)
                    .foregroundStyle(.green)
                    .font(.subheadline)
                LabeledContent("Used", value: "\(Int(viewModel.diskInfo.usedPercentage * 100))%")
                    .font(.subheadline)
            } header: {
                Label("Disk", systemImage: "externaldrive")
            }

            Section {
                ForEach(viewModel.filteredCategories) { category in
                    HStack(spacing: 10) {
                        Button {
                            viewModel.selectCategory(category, selected: !viewModel.selectedCategories.contains(category))
                        } label: {
                            Image(systemName: viewModel.selectedCategories.contains(category) ? "checkmark.square.fill" : "square")
                                .font(.body)
                                .foregroundStyle(viewModel.selectedCategories.contains(category) ? .blue : .secondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)

                        Image(systemName: category.iconName)
                            .foregroundStyle(category.tint)
                            .frame(width: 18)

                        Text(category.rawValue)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        if let result = viewModel.scanResults[category], result.totalSize > 0 {
                            Text(result.formattedTotalSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(category)
                }
            } header: {
                HStack {
                    Text("Categories")
                    Spacer()
                    if viewModel.selectedCategories.count == viewModel.filteredCategories.count {
                        Button("None") { viewModel.deselectAll() }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("All") { viewModel.selectAll() }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .disabled(viewModel.isOperating)
    }

    private var detailPanel: some View {
        Group {
            switch viewModel.phase {
            case .idle:
                DashboardView(viewModel: viewModel)
            case .scanned:
                if let cat = viewModel.selectedCategory, viewModel.scanResults[cat] != nil {
                    CategoryFilesView(category: cat, viewModel: viewModel)
                } else {
                    DashboardView(viewModel: viewModel)
                }
            case .scanning(let category, let progress):
                ScanProgressView(currentCategory: category, progress: progress)
            case .cleaning(let progress):
                CleaningProgressView(progress: progress, category: viewModel.cleanupResults.last?.category.rawValue ?? "")
            case .complete:
                CompleteView(viewModel: viewModel)
            }
        }
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private var iosBody: some View {
        NavigationStack {
            DashboardView(viewModel: viewModel)
                .navigationTitle("Cleaner")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                        .disabled(viewModel.isOperating)
                    }
                }
        }
    }
    #endif

    // MARK: - Toolbar (macOS)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            switch viewModel.phase {
            case .idle, .scanned:
                HStack(spacing: 4) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .disabled(viewModel.isOperating)

                    if viewModel.totalScannableSpace > 0 {
                        Button { viewModel.requestCleanSelected() } label: {
                            Label("Clean", systemImage: "trash")
                        }
                        .disabled(!viewModel.hasSelectedItems || viewModel.isOperating)
                    }
                }
            case .complete:
                Button("Done") { viewModel.dismissComplete() }
            case .scanning, .cleaning:
                if viewModel.isOperating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .controlSize(.small)
                }
            }
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @Bindable var viewModel: CleanupViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DiskGaugeView(diskInfo: viewModel.diskInfo)
                    .frame(maxWidth: 280)

                if viewModel.totalScannableSpace > 0 {
                    recoverableCard
                } else if case .scanned = viewModel.phase {
                    ContentUnavailableView {
                        Label("Nothing to Clean", systemImage: "checkmark.circle")
                    } description: {
                        Text("All scanned categories are empty. Your system looks clean!")
                    }
                } else if case .scanning = viewModel.phase {
                    EmptyView()
                } else {
                    scanningPrompt
                }

                #if os(iOS)
                if viewModel.totalScannableSpace > 0 || viewModel.phase == .scanned {
                    iosCategoryList
                }
                #endif

                if !viewModel.cleanupResults.isEmpty {
                    lastCleanupBanner
                }

                Spacer(minLength: 60)
            }
            .padding(24)
        }
        #if os(macOS)
        .background(Color(.sRGB, red: 0.95, green: 0.95, blue: 0.97).opacity(0.4))
        #endif
    }

    private var recoverableCard: some View {
        VStack(spacing: 12) {
            Text("Recoverable Space")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.formatBytes(viewModel.totalScannableSpace))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                )

            Text("\(viewModel.selectedCategories.count) of \(viewModel.filteredCategories.count) categories selected")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if viewModel.selectedScannableSpace < viewModel.totalScannableSpace {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.orange)
                        .frame(width: max(4, CGFloat(viewModel.selectedScannableSpace) / CGFloat(viewModel.totalScannableSpace) * 200), height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                        .frame(width: max(4, CGFloat(viewModel.totalScannableSpace - viewModel.selectedScannableSpace) / CGFloat(viewModel.totalScannableSpace) * 200), height: 6)
                }
                .frame(width: 200)
            }

            Button(action: { viewModel.requestCleanSelected() }) {
                Label("Clean (\(viewModel.formatBytes(viewModel.selectedScannableSpace)))", systemImage: "trash")
                    .font(.headline)
                    .frame(maxWidth: 260, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!viewModel.hasSelectedItems || viewModel.isOperating)
        }
        .padding(24)
        .background(.background, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var scanningPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Scan your system to find files that can be safely removed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    #if os(iOS)
    private var iosCategoryList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.filteredCategories.enumerated()), id: \.element.id) { index, cat in
                NavigationLink(value: cat) {
                    CleanupRowView(
                        category: cat,
                        scanResult: viewModel.scanResults[cat],
                        isSelected: viewModel.selectedCategories.contains(cat),
                        showCheckbox: true,
                        onToggle: { viewModel.selectCategory(cat, selected: !viewModel.selectedCategories.contains(cat)) }
                    )
                }
                .disabled(viewModel.isOperating)

                if index < viewModel.filteredCategories.count - 1 {
                    Divider().padding(.leading, 42)
                }
            }
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        .navigationDestination(for: CleanupCategory.self) { cat in
            CategoryFilesView(category: cat, viewModel: viewModel)
                .navigationTitle(cat.rawValue)
        }
    }
    #endif

    private var lastCleanupBanner: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Last cleaned: \(viewModel.formatBytes(viewModel.totalFreedSpace))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear") { viewModel.cleanupResults = [] }
                .font(.caption)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
    }
}

// MARK: - Disk Gauge

struct DiskGaugeView: View {
    let diskInfo: AppState

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary.opacity(0.3), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: diskInfo.usedPercentage)
                    .stroke(
                        AngularGradient(
                            colors: diskInfo.usedPercentage > 0.9 ? [.red, .orange] : diskInfo.usedPercentage > 0.75 ? [.orange, .yellow] : [.green, .blue, .green],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: .init(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 1), value: diskInfo.usedPercentage)

                VStack(spacing: 2) {
                    Text("\(Int(diskInfo.usedPercentage * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            diskInfo.usedPercentage > 0.9 ? .red : diskInfo.usedPercentage > 0.75 ? .orange : .primary
                        )
                    Text("used")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 160, height: 160)

            HStack(spacing: 20) {
                Label(diskInfo.formattedFree, systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("|")
                    .foregroundStyle(.tertiary)
                Label(diskInfo.formattedUsed, systemImage: "square.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Complete

struct CompleteView: View {
    @Bindable var viewModel: CleanupViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .speed(0.5), value: viewModel.cleanupResults.count)

            Text("Cleaning Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("Freed \(viewModel.formatBytes(viewModel.totalFreedSpace))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.cleanupResults) { result in
                    HStack {
                        Image(systemName: result.hasErrors ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(result.hasErrors ? .orange : .green)
                        Text(result.category.rawValue)
                            .font(.subheadline)
                        Spacer()
                        Text(result.formattedSpace)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Text("(\(result.filesRemoved))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.background, in: .rect(cornerRadius: 12))

            if viewModel.totalErrors > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("\(viewModel.totalErrors) error\(viewModel.totalErrors == 1 ? "" : "s") occurred")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button("Done") { viewModel.dismissComplete() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Scan Again", systemImage: "arrow.clockwise") {
                    Task { await viewModel.scanAll() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .disabled(viewModel.isOperating)
        }
        .padding(40)
        .frame(maxWidth: 480)
    }
}

// MARK: - Category Files

struct CategoryFilesView: View {
    let category: CleanupCategory
    @Bindable var viewModel: CleanupViewModel
    @State private var sortAscending = false

    var body: some View {
        Group {
            if let result = viewModel.scanResults[category] {
                List {
                    Section("Summary") {
                        LabeledContent("Items Found", value: "\(result.itemCount)")
                        LabeledContent("Total Size", value: result.formattedTotalSize)
                        LabeledContent("Scan Duration", value: String(format: "%.1f sec", result.duration))
                    }

                    if !result.items.isEmpty {
                        Section {
                            ForEach(sortedItems(result.items)) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                        .foregroundStyle(item.isDirectory ? category.tint : .secondary)
                                        .font(.subheadline)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.fileName)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(item.parentPath)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(item.formattedSize)
                                        .font(.subheadline)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            HStack {
                                Text("Files")
                                    .font(.subheadline)
                                Spacer()
                                Button { withAnimation { sortAscending.toggle() } } label: {
                                    HStack(spacing: 2) {
                                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                        Text("Size")
                                    }
                                    .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            viewModel.requestCleanCategory(category)
                        } label: {
                            Label("Clean Category (\(result.formattedTotalSize))", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(result.totalSize == 0 || viewModel.isOperating)
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #endif
                .navigationTitle(category.rawValue)
            } else {
                ContentUnavailableView {
                    Label("No Data", systemImage: "tray")
                } description: {
                    Text("Scan this category to see its contents.")
                }
            }
        }
    }

    private func sortedItems(_ items: [ScannedItem]) -> [ScannedItem] {
        sortAscending ? items.sorted { $0.size < $1.size } : items.sorted { $0.size > $1.size }
    }
}
