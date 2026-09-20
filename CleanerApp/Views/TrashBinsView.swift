import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TrashBinsView: View {
    @Bindable var viewModel: CleanupViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if let result = viewModel.trashScanResult {
                if result.items.isEmpty {
                    ContentUnavailableView {
                        Label("Trash is Empty", systemImage: "trash.slash")
                            .foregroundStyle(.green)
                    } description: {
                        Text("No deleted items currently in the Trash bin.")
                    }
                } else {
                    List {
                        ForEach(result.items) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(.gray)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.fileName)
                                        .font(.headline)
                                    Text(item.parentPath)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(item.formattedSize)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                #if os(macOS)
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                } label: {
                                    Image(systemName: "folder")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                #endif
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    #if os(macOS)
                    .listStyle(.inset)
                    #endif
                }
            } else {
                ContentUnavailableView {
                    Label("Trash Bins", systemImage: "trash.fill")
                } description: {
                    Text("Inspect and safely purge files sitting in the macOS Trash.")
                } actions: {
                    Button("Scan Trash", systemImage: "magnifyingglass") {
                        Task { await viewModel.scanTrash() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()
            footerBar
        }
        .navigationTitle("Trash Bins")
        .onAppear {
            if viewModel.trashScanResult == nil {
                Task { await viewModel.scanTrash() }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trash Bins")
                    .font(.headline)
                Text("Empty system and external drive Trash bins securely")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.scanTrash() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var footerBar: some View {
        let count = viewModel.trashScanResult?.itemCount ?? 0
        let size = viewModel.trashScanResult?.totalSize ?? 0

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) items in Trash")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Occupying: \(viewModel.formatBytes(size))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                if let res = viewModel.trashScanResult {
                    Task {
                        _ = FileTrashService.delete(items: res.items)
                        await viewModel.scanTrash()
                        viewModel.refreshDiskInfo()
                    }
                }
            } label: {
                Label("Empty Trash", systemImage: "trash.slash.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(count == 0)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
