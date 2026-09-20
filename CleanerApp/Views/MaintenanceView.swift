import SwiftUI

struct MaintenanceView: View {
    @Bindable var viewModel: CleanupViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                memoryOverviewCard

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Maintenance Scripts & Optimizations")
                            .font(.headline)
                        Spacer()
                        Button("Run All Tasks") {
                            Task { await viewModel.runAllMaintenanceTasks() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    ForEach(viewModel.maintenanceTasks) { task in
                        taskRow(task)
                    }
                }
                .padding(20)
                .background(.background, in: .rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .navigationTitle("Maintenance")
        .onAppear {
            viewModel.refreshMemoryInfo()
        }
    }

    private var memoryOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System Memory (RAM)")
                        .font(.headline)
                    Text("\(viewModel.systemMemory.formattedFree) available of \(viewModel.systemMemory.formattedTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await viewModel.runMaintenanceTask(id: "free_ram") }
                } label: {
                    Label("Free Up RAM", systemImage: "bolt.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // Memory Breakdown Progress Bar
            VStack(spacing: 6) {
                ProgressView(value: viewModel.systemMemory.usedPercentage)
                    .progressViewStyle(.linear)
                    .tint(viewModel.systemMemory.usedPercentage > 0.85 ? .red : viewModel.systemMemory.usedPercentage > 0.7 ? .orange : .green)

                HStack {
                    Label("App Memory: \(viewModel.formatBytes(viewModel.systemMemory.appMemory))", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Spacer()
                    Label("Wired: \(viewModel.formatBytes(viewModel.systemMemory.wiredMemory))", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Spacer()
                    Label("Free: \(viewModel.systemMemory.formattedFree)", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func taskRow(_ task: MaintenanceTaskItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: task.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let msg = task.statusMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                }
            }

            Spacer()

            if task.isRunning {
                ProgressView()
                    .controlSize(.small)
            } else if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button("Run") {
                    Task { await viewModel.runMaintenanceTask(id: task.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
    }
}
