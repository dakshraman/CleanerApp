import SwiftUI

struct ScanProgressView: View {
    let currentCategory: String
    let progress: Double
    var onCancel: (() -> Void)? = nil

    @State private var rotation = 0.0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.quaternary.opacity(0.3), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: .init(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.3), value: progress)

                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
            }
            .frame(width: 84, height: 84)

            VStack(spacing: 6) {
                Text("Scanning System...")
                    .font(.title3)
                    .fontWeight(.semibold)

                if !currentCategory.isEmpty {
                    Text(currentCategory)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }

            VStack(spacing: 8) {
                ProgressView(value: max(0.02, progress))
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .frame(maxWidth: 240)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let onCancel {
                Button("Cancel Scan", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct CleaningProgressView: View {
    let progress: Double
    let category: String
    var onCancel: (() -> Void)? = nil

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.quaternary.opacity(0.3), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(
                        LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: .init(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.3), value: progress)

                Image(systemName: "trash.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
                    .scaleEffect(isPulsing ? 1.15 : 0.95)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                    .onAppear { isPulsing = true }
            }
            .frame(width: 84, height: 84)

            VStack(spacing: 6) {
                Text("Cleaning Files...")
                    .font(.title3)
                    .fontWeight(.semibold)

                if !category.isEmpty {
                    Text(category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                ProgressView(value: max(0.02, progress))
                    .progressViewStyle(.linear)
                    .tint(.red)
                    .frame(maxWidth: 240)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let onCancel {
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
