import SwiftUI

struct PrivacyModuleView: View {
    @Bindable var viewModel: CleanupViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if let result = viewModel.privacyScanResult {
                List {
                    ForEach(result.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.purple)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.groupTag ?? item.fileName)
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
                        }
                        .padding(.vertical, 4)
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #endif
            } else {
                ContentUnavailableView {
                    Label("Privacy Protection", systemImage: "hand.raised.fill")
                } description: {
                    Text("Scan and remove browsing traces, cookies, and tracking databases.")
                } actions: {
                    Button("Scan Privacy Traces", systemImage: "magnifyingglass") {
                        Task { await viewModel.scanPrivacy() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()
            footerBar
        }
        .navigationTitle("Privacy")
        .onAppear {
            if viewModel.privacyScanResult == nil {
                Task { await viewModel.scanPrivacy() }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy & Browsing Traces")
                    .font(.headline)
                Text("Safely wipe browser histories, cookies, and autofill traces")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.scanPrivacy() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var footerBar: some View {
        let count = viewModel.privacyScanResult?.itemCount ?? 0
        let size = viewModel.privacyScanResult?.totalSize ?? 0

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) privacy items found")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Traces: \(viewModel.formatBytes(size))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                if let res = viewModel.privacyScanResult {
                    Task {
                        _ = FileTrashService.delete(items: res.items)
                        await viewModel.scanPrivacy()
                    }
                }
            } label: {
                Label("Wipe Privacy Traces", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(count == 0)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
