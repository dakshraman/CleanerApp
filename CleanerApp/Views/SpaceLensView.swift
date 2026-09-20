import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SpaceLensView: View {
    @Bindable var viewModel: CleanupViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if viewModel.isScanningSpaceLens {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Analyzing Disk Storage Distribution...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.spaceLensItems.isEmpty {
                ContentUnavailableView {
                    Label("Space Lens", systemImage: "circle.hexagongrid.fill")
                } description: {
                    Text("Build a visual map of your largest directories and storage consumers.")
                } actions: {
                    Button("Scan Storage Map", systemImage: "arrow.clockwise") {
                        Task { await viewModel.scanSpaceLens() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        storageProportionsBar

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(viewModel.spaceLensItems) { item in
                                folderCard(item)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Space Lens")
        .onAppear {
            if viewModel.spaceLensItems.isEmpty {
                Task { await viewModel.scanSpaceLens() }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Space Lens")
                    .font(.headline)
                Text("Visual breakdown of your storage by folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.scanSpaceLens() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Re-analyze Storage")
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var storageProportionsBar: some View {
        let total = viewModel.spaceLensItems.reduce(Int64(0)) { $0 + $1.size }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Storage Footprint (\(viewModel.formatBytes(total)))")
                .font(.headline)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(viewModel.spaceLensItems) { item in
                        let ratio = total > 0 ? CGFloat(item.size) / CGFloat(total) : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.color)
                            .frame(width: max(4, ratio * geo.size.width))
                            .help("\(item.name): \(item.formattedSize)")
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func folderCard(_ item: SpaceLensItem) -> some View {
        let total = viewModel.spaceLensItems.reduce(Int64(0)) { $0 + $1.size }
        let percentage = total > 0 ? Double(item.size) / Double(total) * 100 : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundStyle(item.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.path.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                #if os(macOS)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.path])
                } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reveal in Finder")
                #endif
            }

            HStack {
                Text(item.formattedSize)
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()

                Spacer()

                Text("\(Int(percentage))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: percentage / 100.0)
                .progressViewStyle(.linear)
                .tint(item.color)
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
