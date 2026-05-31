import Foundation

final class LargeFileService: CleanupService {
    private let scanPaths = [
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Documents",
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Movies",
        NSHomeDirectory() + "/Music",
        NSHomeDirectory() + "/Pictures"
    ]
    private let minimumSize: Int64 = 100 * 1024 * 1024

    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        for path in scanPaths {
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path),
                  let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            while let fileURL = enumerator.nextObject() as? URL {
                guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                      let fileSize = attrs[.size] as? Int64,
                      fileSize >= minimumSize else { continue }
                items.append(ScannedItem(
                    url: fileURL,
                    size: fileSize,
                    isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
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
