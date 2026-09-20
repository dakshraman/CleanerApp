import Foundation

final class CacheCleanerService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        if let userCacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first,
           fm.fileExists(atPath: userCacheDir.path) {
            items += scanTopLevelCaches(at: userCacheDir, fm: fm)
        }

        #if os(macOS)
        let systemCachePath = URL(fileURLWithPath: "/Library/Caches")
        if fm.fileExists(atPath: systemCachePath.path) {
            items += scanTopLevelCaches(at: systemCachePath, fm: fm)
        }
        #endif

        items.sort { $0.size > $1.size }
        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .systemCache, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func scanTopLevelCaches(at rootDir: URL, fm: FileManager) -> [ScannedItem] {
        guard let contents = try? fm.contentsOfDirectory(
            at: rootDir,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [ScannedItem] = []

        for item in contents {
            if Task.isCancelled { break }
            let name = item.lastPathComponent
            // Don't flag special system essentials or hidden items
            if name.hasPrefix(".") || name == "CloudKit" { continue }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir) else { continue }

            let size: Int64
            let attrs = try? fm.attributesOfItem(atPath: item.path)
            let dateCreated = attrs?[.creationDate] as? Date
            let dateModified = attrs?[.modificationDate] as? Date

            if isDir.boolValue {
                size = directorySize(item, fm: fm)
            } else {
                size = (attrs?[.size] as? Int64) ?? 0
            }

            // Only report items with meaningful size (> 4 KB)
            guard size >= 4096 else { continue }

            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: isDir.boolValue,
                dateCreated: dateCreated,
                dateModified: dateModified
            ))
        }

        return items
    }

    private func directorySize(_ url: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64,
               (attrs[.type] as? FileAttributeType) == .typeRegular {
                total += size
            }
        }
        return total
    }
}
