import Foundation

enum RemovalMethod: String, Sendable {
    case trash = "Moved to Trash"
    case delete = "Deleted"
}

struct CleanupResult: Identifiable, Sendable {
    let id = UUID()
    let category: CleanupCategory
    let filesRemoved: Int
    let spaceFreed: Int64
    let errors: [String]
    let duration: TimeInterval
    let method: RemovalMethod

    nonisolated init(
        category: CleanupCategory,
        filesRemoved: Int,
        spaceFreed: Int64,
        errors: [String],
        duration: TimeInterval,
        method: RemovalMethod = .delete
    ) {
        self.category = category
        self.filesRemoved = filesRemoved
        self.spaceFreed = spaceFreed
        self.errors = errors
        self.duration = duration
        self.method = method
    }

    var formattedSpace: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: spaceFreed)
    }

    var hasErrors: Bool { !errors.isEmpty }
}

struct ScannedItem: Identifiable, Sendable, Hashable {
    let id: UUID
    let url: URL
    let size: Int64
    let isDirectory: Bool
    let dateCreated: Date?
    let dateModified: Date?
    let groupTag: String?

    nonisolated init(
        id: UUID = UUID(),
        url: URL,
        size: Int64,
        isDirectory: Bool,
        dateCreated: Date? = nil,
        dateModified: Date? = nil,
        groupTag: String? = nil
    ) {
        self.id = id
        self.url = url
        self.size = size
        self.isDirectory = isDirectory
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.groupTag = groupTag
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    nonisolated var fileName: String { url.lastPathComponent }
    nonisolated var parentPath: String { url.deletingLastPathComponent().path }

    var formattedModifiedDate: String {
        guard let dateModified else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: dateModified, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScannedItem, rhs: ScannedItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ScanResult: Identifiable, Sendable {
    let id: UUID
    let category: CleanupCategory
    let items: [ScannedItem]
    let totalSize: Int64
    let duration: TimeInterval

    nonisolated init(
        id: UUID = UUID(),
        category: CleanupCategory,
        items: [ScannedItem],
        totalSize: Int64,
        duration: TimeInterval
    ) {
        self.id = id
        self.category = category
        self.items = items
        self.totalSize = totalSize
        self.duration = duration
    }

    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    var itemCount: Int { items.count }
}

struct AppState: Sendable {
    var totalDiskSpace: Int64 = 0
    var usedDiskSpace: Int64 = 0
    var freeDiskSpace: Int64 = 0

    var formattedFree: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: freeDiskSpace)
    }

    var formattedUsed: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: usedDiskSpace)
    }

    var formattedTotal: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalDiskSpace)
    }

    var usedPercentage: Double {
        totalDiskSpace > 0 ? Double(usedDiskSpace) / Double(totalDiskSpace) : 0
    }
}
