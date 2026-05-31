import Foundation

final class TempFilesCleanerService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory

        guard let enumerator = fm.enumerator(at: tempDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return ScanResult(category: .tempFiles, items: [], totalSize: 0, duration: Date().timeIntervalSince(start))
        }

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

        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .tempFiles, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }
}
