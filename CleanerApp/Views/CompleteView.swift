import SwiftUI

struct CompleteView: View {
    @Bindable var viewModel: CleanupViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .speed(0.6), value: viewModel.cleanupResults.count)

            Text("Cleaning Complete!")
                .font(.title2)
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
                        Text("(\(result.filesRemoved) items)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.background, in: .rect(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)

            if viewModel.totalErrors > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("\(viewModel.totalErrors) error\(viewModel.totalErrors == 1 ? "" : "s") occurred during removal.")
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
        .padding(36)
        .frame(maxWidth: 480)
    }
}
