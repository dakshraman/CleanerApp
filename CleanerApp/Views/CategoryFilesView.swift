import SwiftUI
#if os(macOS)
import AppKit
#endif

enum SortOption: String, CaseIterable, Identifiable {
    case sizeDesc = "Size (Largest)"
    case sizeAsc = "Size (Smallest)"
    case name = "Name"
    case date = "Date Modified"

    var id: String { rawValue }
}

struct CategoryFilesView: View {
    let category: CleanupCategory
    @Bindable var viewModel: CleanupViewModel
    @State private var searchText = ""
    @State private var sortOption: SortOption = .sizeDesc

    var body: some View {
        Group {
            if let result = viewModel.scanResults[category] {
                VStack(spacing: 0) {
                    headerSection(result: result)
                    Divider()

                    if result.items.isEmpty {
                        ContentUnavailableView {
                            Label("Category is Clean", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                        } description: {
                            Text("No files in \(category.rawValue) need cleaning.")
                        }
                    } else {
                        fileList(items: filteredAndSortedItems(result.items))
                    }

                    Divider()
                    footerActionBar(result: result)
                }
                .navigationTitle(category.rawValue)
            } else {
                ContentUnavailableView {
                    Label("No Scan Data", systemImage: "tray")
                } description: {
                    Text("Scan this category to inspect removable files.")
                } actions: {
                    Button("Scan \(category.rawValue)") {
                        Task { await viewModel.scanSingleCategory(category) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func headerSection(result: ScanResult) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.headline)
                Text("\(result.itemCount) items found • \(result.formattedTotalSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search files...", text: $searchText)
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

            // Sort Menu
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func fileList(items: [ScannedItem]) -> some View {
        List {
            Section {
                ForEach(items) { item in
                    let isSelected = viewModel.isItemSelected(item, in: category)

                    HStack(spacing: 10) {
                        Button {
                            viewModel.toggleItemSelection(item, in: category)
                        } label: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .blue : .secondary.opacity(0.4))
                                .font(.body)
                        }
                        .buttonStyle(.plain)

                        Image(systemName: fileIcon(for: item))
                            .foregroundStyle(item.isDirectory ? category.tint : .secondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.fileName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)

                                if let tag = item.groupTag {
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.blue.opacity(0.1), in: .capsule)
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                }
                            }

                            Text(item.parentPath)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.formattedSize)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()

                            Text(item.formattedModifiedDate)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        #if os(macOS)
                        Button {
                            revealInFinder(item.url)
                        } label: {
                            Image(systemName: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Reveal in Finder")
                        #endif
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .contextMenu {
                        #if os(macOS)
                        Button("Reveal in Finder") {
                            revealInFinder(item.url)
                        }
                        Button("Open File") {
                            NSWorkspace.shared.open(item.url)
                        }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.url.path, forType: .string)
                        }
                        Divider()
                        #endif
                        Button(isSelected ? "Deselect" : "Select") {
                            viewModel.toggleItemSelection(item, in: category)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("\(items.count) matching items")
                    Spacer()
                    Button("Select All") { viewModel.selectAllItems(in: category) }
                        .font(.caption)
                        .buttonStyle(.plain)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Button("Deselect All") { viewModel.deselectAllItems(in: category) }
                        .font(.caption)
                        .buttonStyle(.plain)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }

    private func footerActionBar(result: ScanResult) -> some View {
        let selectedSpace = viewModel.selectedSpace(for: category)
        let selectedCount = viewModel.selectedItemCount(for: category)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedCount) of \(result.itemCount) items selected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Will free: \(viewModel.formatBytes(selectedSpace))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.requestCleanCategory(category)
            } label: {
                Label("Clean Selected (\(viewModel.formatBytes(selectedSpace)))", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedCount == 0 || viewModel.isOperating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func filteredAndSortedItems(_ items: [ScannedItem]) -> [ScannedItem] {
        var result = items
        if !searchText.isEmpty {
            result = result.filter {
                $0.fileName.localizedCaseInsensitiveContains(searchText) ||
                $0.parentPath.localizedCaseInsensitiveContains(searchText) ||
                ($0.groupTag?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch sortOption {
        case .sizeDesc:
            result.sort { $0.size > $1.size }
        case .sizeAsc:
            result.sort { $0.size < $1.size }
        case .name:
            result.sort { $0.fileName.localizedCompare($1.fileName) == .orderedAscending }
        case .date:
            result.sort { ($0.dateModified ?? .distantPast) > ($1.dateModified ?? .distantPast) }
        }

        return result
    }

    private func fileIcon(for item: ScannedItem) -> String {
        if item.isDirectory { return "folder.fill" }
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "dmg", "pkg", "iso", "zip", "tar", "gz":
            return "archivebox.fill"
        case "mp4", "mov", "mkv", "avi":
            return "film.fill"
        case "mp3", "m4a", "wav", "flac":
            return "music.note"
        case "png", "jpg", "jpeg", "heic", "gif":
            return "photo.fill"
        case "swift", "c", "cpp", "py", "js", "html", "json", "plist":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }

    #if os(macOS)
    private func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    #endif
}
