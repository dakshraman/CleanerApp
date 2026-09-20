import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MenuBarWidgetView: View {
    @State private var memory = MaintenanceService.shared.getMemoryInfo()
    @State private var diskFree = FileManager.freeDiskSpace
    @State private var diskTotal = FileManager.totalDiskSpace
    @State private var isCleaning = false
    @State private var cleanDoneMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("MacPurge Monitor")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Memory
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Memory (RAM)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(memory.usedPercentage * 100))% used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: memory.usedPercentage)
                    .progressViewStyle(.linear)
                    .tint(memory.usedPercentage > 0.85 ? .red : .blue)

                Text("\(memory.formattedFree) available of \(memory.formattedTotal)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Disk
            let diskUsed = diskTotal - diskFree
            let diskRatio = diskTotal > 0 ? Double(diskUsed) / Double(diskTotal) : 0

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Macintosh HD")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(diskRatio * 100))% used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: diskRatio)
                    .progressViewStyle(.linear)
                    .tint(diskRatio > 0.85 ? .orange : .green)

                Text("\(ByteCountFormatter.string(fromByteCount: diskFree, countStyle: .file)) free")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let msg = cleanDoneMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            Divider()

            HStack {
                Button {
                    isCleaning = true
                    Task {
                        _ = await MaintenanceService.shared.runTask(id: "free_ram")
                        memory = MaintenanceService.shared.getMemoryInfo()
                        isCleaning = false
                        cleanDoneMessage = "Freed inactive RAM!"
                    }
                } label: {
                    if isCleaning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Free RAM", systemImage: "bolt.fill")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Open Main Window") {
                    #if os(macOS)
                    NSApp.activate(ignoringOtherApps: true)
                    #endif
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 260)
        .onAppear {
            memory = MaintenanceService.shared.getMemoryInfo()
            diskFree = FileManager.freeDiskSpace
            diskTotal = FileManager.totalDiskSpace
        }
    }
}
