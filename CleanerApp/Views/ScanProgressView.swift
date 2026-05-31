import SwiftUI

struct ScanProgressView: View {
    let currentCategory: String
    let progress: Double

    @State private var rotation = 0.0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.quaternary.opacity(0.3), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: .init(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.3), value: progress)

                Image(systemName: "magnifyingglass")
                    .font(.title)
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            }
            .frame(width: 80, height: 80)

            VStack(spacing: 4) {
                Text("Scanning...")
                    .font(.headline)
                if !currentCategory.isEmpty {
                    Text(currentCategory)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.blue)
                .frame(maxWidth: 200)

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct CleaningProgressView: View {
    let progress: Double
    let category: String

    @State private var scale: CGFloat = 1

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trash")
                .font(.system(size: 40))
                .foregroundStyle(.red)
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        scale = 1.2
                    }
                }

            VStack(spacing: 4) {
                Text("Cleaning...")
                    .font(.headline)
                if !category.isEmpty {
                    Text(category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.red)
                .frame(maxWidth: 200)

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
