import SwiftUI

struct SmartCareView: View {
    @Bindable var viewModel: CleanupViewModel
    @State private var pulseAnimation = false
    @State private var rotationAngle = 0.0

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroHeader

                if viewModel.isSmartScanning {
                    scanningHero
                } else if viewModel.smartCleanCompleted {
                    cleanedHero
                } else if viewModel.smartScanCompleted {
                    readyToCleanHero
                } else {
                    idleHero
                }

                healthPillarsGrid

                Spacer(minLength: 40)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.06), Color.purple.opacity(0.04), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 6) {
            Text("Smart Care")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Complete one-click cleaning, security check, and performance tuning")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - States

    private var idleHero: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(colors: [.blue, .cyan, .purple, .pink, .blue], center: .center),
                        lineWidth: 6
                    )
                    .frame(width: 170, height: 170)
                    .shadow(color: .blue.opacity(0.4), radius: 16)
                    .scaleEffect(pulseAnimation ? 1.04 : 0.98)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                    .onAppear { pulseAnimation = true }

                Button {
                    Task { await viewModel.runSmartScan() }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 38))
                            .foregroundStyle(.white)
                        Text("Scan")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 140, height: 140)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .circle
                    )
                    .shadow(color: .purple.opacity(0.4), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }

            Text("Click Scan to analyze system junk, malware, and performance")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var scanningHero: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.quaternary.opacity(0.3), lineWidth: 8)
                    .frame(width: 170, height: 170)

                Circle()
                    .trim(from: 0, to: max(0.05, viewModel.smartScanProgress))
                    .stroke(
                        AngularGradient(colors: [.cyan, .blue, .purple, .pink, .cyan], center: .center),
                        style: .init(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.4), value: viewModel.smartScanProgress)

                VStack(spacing: 4) {
                    Text("\(Int(viewModel.smartScanProgress * 100))%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text("Analyzing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text(viewModel.smartCurrentStage)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .transition(.opacity)

                Button("Cancel", role: .cancel) {
                    viewModel.cancelOperation()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var readyToCleanHero: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(viewModel.formatBytes(viewModel.smartCleanupSpace))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Junk and cache files ready to clean safely")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await viewModel.runSmartClean() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("Run Smart Clean")
                }
                .font(.headline)
                .frame(minWidth: 220, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .shadow(color: .orange.opacity(0.3), radius: 8, y: 3)
            .disabled(viewModel.isOperating)
        }
    }

    private var cleanedHero: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: viewModel.smartCleanCompleted)

            VStack(spacing: 4) {
                Text("Your Mac is Clean & Optimized!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Freed \(viewModel.formatBytes(viewModel.totalFreedSpace)) and released inactive RAM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Done") {
                viewModel.smartScanCompleted = false
                viewModel.smartCleanCompleted = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - 4 Health Pillars Grid

    private var healthPillarsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            pillarCard(
                title: "System Cleanup",
                subtitle: viewModel.smartScanCompleted ? "\(viewModel.formatBytes(viewModel.smartCleanupSpace)) junk files found" : "Caches, logs, and leftovers",
                icon: "archivebox.fill",
                color: .blue,
                status: viewModel.smartScanCompleted ? (viewModel.smartCleanupSpace > 0 ? .warning : .clean) : .idle,
                targetTab: .systemJunk
            )

            pillarCard(
                title: "Protection",
                subtitle: viewModel.smartScanCompleted ? (viewModel.smartMalwareCount > 0 ? "\(viewModel.smartMalwareCount) threats detected" : "No malware threats found") : "Adware & suspicious agents",
                icon: "shield.lefthalf.filled",
                color: .pink,
                status: viewModel.smartScanCompleted ? (viewModel.smartMalwareCount > 0 ? .danger : .clean) : .idle,
                targetTab: .malwareRemoval
            )

            pillarCard(
                title: "Speed & RAM",
                subtitle: "\(viewModel.systemMemory.formattedUsed) RAM used of \(viewModel.systemMemory.formattedTotal)",
                icon: "bolt.fill",
                color: .orange,
                status: viewModel.smartScanCompleted ? .warning : .idle,
                targetTab: .maintenance
            )

            pillarCard(
                title: "Applications",
                subtitle: viewModel.smartScanCompleted ? "\(viewModel.smartLeftoversCount) app remnants found" : "Uninstaller & leftovers",
                icon: "xmark.bin.fill",
                color: .purple,
                status: viewModel.smartScanCompleted ? (viewModel.smartLeftoversCount > 0 ? .warning : .clean) : .idle,
                targetTab: .uninstaller
            )
        }
        .frame(maxWidth: 640)
    }

    private func pillarCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        status: PillarStatus,
        targetTab: NavigationTab
    ) -> some View {
        Button {
            viewModel.selectedTab = targetTab
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                switch status {
                case .idle:
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                case .clean:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                case .warning:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                case .danger:
                    Image(systemName: "xmark.octagon.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .background(.background, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

enum PillarStatus {
    case idle
    case clean
    case warning
    case danger
}
