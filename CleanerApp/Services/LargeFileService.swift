import Foundation

final class LargeFileService: CleanupService {
    let minimumSizeMB: Int

    init(minimumSizeMB: Int = 100) {
        self.minimumSizeMB = minimumSizeMB
    }

    private var minimumSize: Int64 {
        Int64(minimumSizeMB) * 1024 * 1024
    }

    private var scanPaths: [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Downloads",
            home + "/Documents",
            home + "/Desktop",
            home + "/Movies",
            home + "/Music",
            home + "/Pictures"
        ]
    }

    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        for path in scanPaths {
            if Task.isCancelled { break }
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path),
                  let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                      let fileSize = attrs[.size] as? Int64,
                      fileSize >= minimumSize,
                      attrs[.type] as? FileAttributeType == .typeRegular else { continue }

                items.append(ScannedItem(
                    url: fileURL,
                    size: fileSize,
                    isDirectory: false,
                    dateCreated: attrs[.creationDate] as? Date,
                    dateModified: attrs[.modificationDate] as? Date
                ))
            }
        }

        items.sort { $0.size > $1.size }
        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .largeFiles, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }
}
