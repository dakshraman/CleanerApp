import Foundation

final class TrashCleanerService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default
        let home = NSHomeDirectory()

        let trashURLs = [
            URL(fileURLWithPath: "\(home)/.Trash")
        ]

        for trashDir in trashURLs {
            if Task.isCancelled { break }
            guard fm.fileExists(atPath: trashDir.path),
                  let contents = try? fm.contentsOfDirectory(
                    at: trashDir,
                    includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey, .isDirectoryKey],
                    options: []
                  ) else { continue }

            for item in contents {
                if Task.isCancelled { break }
                guard let attrs = try? fm.attributesOfItem(atPath: item.path) else { continue }
                var isDir: ObjCBool = false
                fm.fileExists(atPath: item.path, isDirectory: &isDir)
                let size = isDir.boolValue ? directorySize(item, fm: fm) : ((attrs[.size] as? Int64) ?? 0)

                items.append(ScannedItem(
                    url: item,
                    size: size,
                    isDirectory: isDir.boolValue,
                    dateCreated: attrs[.creationDate] as? Date,
                    dateModified: attrs[.modificationDate] as? Date
                ))
            }
        }

        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .tempFiles, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func directorySize(_ url: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
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
