import SwiftUI

struct CleanupRowView: View {
    let category: CleanupCategory
    let scanResult: ScanResult?
    let isSelected: Bool
    let showCheckbox: Bool
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            if showCheckbox {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .blue : .secondary.opacity(0.3))
                        .contentTransition(.symbolEffect(.automatic))
                }
                .buttonStyle(.plain)
            }

            Image(systemName: category.iconName)
                .font(.title3)
                .foregroundStyle(category.tint)
                .frame(width: 24)
                .symbolVariant(scanResult != nil && scanResult!.totalSize > 0 ? .fill : .none)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.body)
                    .fontWeight(.medium)
                Text(category.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let result = scanResult, result.totalSize > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(result.formattedTotalSize)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text("\(result.itemCount) item\(result.itemCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else if scanResult != nil {
                Text("Empty")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isHovering ? Color.primary.opacity(0.04) : .clear, in: .rect(cornerRadius: 8))
        .onHover { hovering in isHovering = hovering }
    }
}
