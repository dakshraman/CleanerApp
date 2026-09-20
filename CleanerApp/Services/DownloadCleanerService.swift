import Foundation

final class DownloadCleanerService: CleanupService {
    let minAgeDays: Int

    init(minAgeDays: Int = 30) {
        self.minAgeDays = minAgeDays
    }

    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        guard let downloadsDir = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first,
              fm.fileExists(atPath: downloadsDir.path),
              let contents = try? fm.contentsOfDirectory(
                at: downloadsDir,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else {
            return ScanResult(category: .downloads, items: [], totalSize: 0, duration: Date().timeIntervalSince(start))
        }

        let cutoffDate = minAgeDays > 0 ? Calendar.current.date(byAdding: .day, value: -minAgeDays, to: Date()) : nil

        for item in contents {
            if Task.isCancelled { break }
            guard let attrs = try? fm.attributesOfItem(atPath: item.path) else { continue }

            let dateModified = attrs[.modificationDate] as? Date ?? attrs[.creationDate] as? Date
            if let cutoff = cutoffDate, let modDate = dateModified, modDate > cutoff {
                // Skip recent downloads to protect user from losing newly saved files
                continue
            }

            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            let size: Int64 = isDir.boolValue ? directorySize(item, fm: fm) : ((attrs[.size] as? Int64) ?? 0)

            guard size > 0 else { continue }

            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: isDir.boolValue,
                dateCreated: attrs[.creationDate] as? Date,
                dateModified: attrs[.modificationDate] as? Date
            ))
        }

        items.sort { ($0.dateModified ?? .distantPast) > ($1.dateModified ?? .distantPast) }
        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .downloads, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func directorySize(_ url: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
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
