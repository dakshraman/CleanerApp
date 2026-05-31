import Foundation

final class LogCleanerService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        for path in logPaths {
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path),
                  let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) else { continue }
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
        }

        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .appLogs, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private var logPaths: [String] {
        #if os(macOS)
        [
            NSHomeDirectory() + "/Library/Logs",
            NSHomeDirectory() + "/Library/Application Support/CrashReporter",
            "/Library/Logs"
        ]
        #else
        [
            NSHomeDirectory() + "/Library/Logs",
            NSHomeDirectory() + "/Library/Application Support/CrashReporter"
        ]
        #endif
    }
}
