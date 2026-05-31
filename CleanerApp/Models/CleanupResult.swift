import Foundation

enum RemovalMethod: String {
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

    nonisolated init(category: CleanupCategory, filesRemoved: Int, spaceFreed: Int64, errors: [String], duration: TimeInterval, method: RemovalMethod = .delete) {
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

struct ScannedItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let size: Int64
    let isDirectory: Bool
    let dateCreated: Date?
    let dateModified: Date?

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    nonisolated var fileName: String { url.lastPathComponent }
    nonisolated var parentPath: String { url.deletingLastPathComponent().path }
}

struct ScanResult: Identifiable, Sendable {
    let id = UUID()
    let category: CleanupCategory
    let items: [ScannedItem]
    let totalSize: Int64
    let duration: TimeInterval

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
