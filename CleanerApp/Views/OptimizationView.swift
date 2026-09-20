import SwiftUI
#if os(macOS)
import AppKit
#endif

enum OptimizationFilter: String, CaseIterable, Identifiable {
    case all = "All Items"
    case brokenOnly = "Broken & Leftovers"
    case launchAgents = "Launch Agents"
    case launchDaemons = "Daemons"
    case plugins = "Extensions & Panes"

    var id: String { rawValue }
}

struct OptimizationView: View {
    @Bindable var viewModel: CleanupViewModel
    @State private var filter: OptimizationFilter = .brokenOnly
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if viewModel.isScanningOptimization {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Scanning Login Items, Launch Agents & Background Tasks...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("No Items Matching Filter", systemImage: "checkmark.shield")
                        .foregroundStyle(.green)
                } description: {
                    Text(filter == .brokenOnly ? "No broken login items or orphaned background agents found on your Mac." : "No startup items found.")
                } actions: {
                    Button("Scan Again", systemImage: "arrow.clockwise") {
                        Task { await viewModel.scanOptimizationItems() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                itemsList
            }

            Divider()
            footerBar
        }
        .navigationTitle("Optimization")
        .onAppear {
            if viewModel.startupItems.isEmpty {
                Task { await viewModel.scanOptimizationItems() }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Optimization & Background Items")
                        .font(.headline)
                    Text("Find and remove leftover startup items, broken daemons, and orphaned background agents")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await viewModel.scanOptimizationItems() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh items")
                .buttonStyle(.plain)
            }

            // Filter picker & search
            HStack(spacing: 12) {
                Picker("Filter", selection: $filter) {
                    ForEach(OptimizationFilter.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $searchText)
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
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 6))
                .frame(maxWidth: 180)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var itemsList: some View {
        List {
            ForEach(filteredItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.itemType.icon)
                        .font(.title2)
                        .foregroundStyle(item.isBroken ? .orange : .blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(item.name)
                                .font(.body)
                                .fontWeight(.medium)

                            if item.isBroken {
                                Text("Broken Leftover")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.15), in: .capsule)
                                    .foregroundStyle(.orange)
                            }

                            Text(item.formattedType)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.05), in: .capsule)
                                .foregroundStyle(.secondary)
                        }

                        Text(item.statusDescription)
                            .font(.caption)
                            .foregroundStyle(item.isBroken ? .secondary : .tertiary)
                            .lineLimit(2)
                    }

                    Spacer()

                    #if os(macOS)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
                    } label: {
                        Image(systemName: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Reveal Plist in Finder")
                    #endif

                    Button(role: .destructive) {
                        Task { await viewModel.removeStartupItem(item) }
                    } label: {
                        Text(item.isBroken ? "Remove Leftover" : "Disable & Delete")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }

    private var footerBar: some View {
        let brokenCount = viewModel.startupItems.filter { $0.isBroken }.count

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.startupItems.count) startup/background items scanned")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(brokenCount) broken leftover items from uninstalled apps")
                    .font(.caption)
                    .foregroundStyle(brokenCount > 0 ? .orange : .secondary)
            }

            Spacer()

            if brokenCount > 0 {
                Button(role: .destructive) {
                    Task { await viewModel.removeAllBrokenStartupItems() }
                } label: {
                    Label("Clean All Broken Items (\(brokenCount))", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var filteredItems: [StartupItem] {
        var list = viewModel.startupItems

        switch filter {
        case .all:
            break
        case .brokenOnly:
            list = list.filter { $0.isBroken }
        case .launchAgents:
            list = list.filter { $0.itemType == .launchAgent }
        case .launchDaemons:
            list = list.filter { $0.itemType == .launchDaemon }
        case .plugins:
            list = list.filter { $0.itemType == .preferencePane || $0.itemType == .quickLookPlugin || $0.itemType == .servicePlugin }
        }

        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.statusDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        return list
    }
}
