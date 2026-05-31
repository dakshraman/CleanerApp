import Foundation

final class CacheCleanerService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        if let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            items += scanDirectory(cacheDir, fm: fm)
        }

        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .systemCache, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func scanDirectory(_ url: URL, fm: FileManager) -> [ScannedItem] {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var items: [ScannedItem] = []
        while let fileURL = enumerator.nextObject() as? URL {
            guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attrs[.size] as? Int64,
                  fileSize > 0 else { continue }
            items.append(ScannedItem(
                url: fileURL,
                size: fileSize,
                isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
                dateCreated: attrs[.creationDate] as? Date,
                dateModified: attrs[.modificationDate] as? Date
            ))
        }
        return items
    }
}
