import Foundation

final class DownloadCleanerService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        guard let downloadsDir = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first,
              fm.fileExists(atPath: downloadsDir.path),
              let contents = try? fm.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey], options: []) else {
            return ScanResult(category: .downloads, items: [], totalSize: 0, duration: Date().timeIntervalSince(start))
        }

        for item in contents {
            guard let attrs = try? fm.attributesOfItem(atPath: item.path),
                  let size = attrs[.size] as? Int64 else { continue }
            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
                dateCreated: attrs[.creationDate] as? Date,
                dateModified: attrs[.modificationDate] as? Date
            ))
        }

        items.sort { $0.dateModified ?? .distantPast > $1.dateModified ?? .distantPast }
        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .downloads, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }
}
