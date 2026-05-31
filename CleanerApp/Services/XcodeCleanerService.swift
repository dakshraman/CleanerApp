import Foundation

final class XcodeCleanerService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        for path in allPaths {
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path) else { continue }
            var isDir: ObjCBool = false
            fm.fileExists(atPath: path, isDirectory: &isDir)
            if isDir.boolValue {
                scanDirectory(url, fm: fm, items: &items)
            } else {
                addFile(url, fm: fm, items: &items)
            }
        }

        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .xcodeDerived, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func scanDirectory(_ url: URL, fm: FileManager, items: inout [ScannedItem]) {
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: []) else { return }
        for item in contents {
            guard let attrs = try? fm.attributesOfItem(atPath: item.path),
                  let fileSize = attrs[.size] as? Int64 else { continue }
            items.append(ScannedItem(
                url: item,
                size: fileSize > 0 ? fileSize : directorySize(item, fm: fm),
                isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
                dateCreated: attrs[.creationDate] as? Date,
                dateModified: attrs[.modificationDate] as? Date
            ))
        }
    }

    private func addFile(_ url: URL, fm: FileManager, items: inout [ScannedItem]) {
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? Int64 else { return }
        items.append(ScannedItem(
            url: url,
            size: fileSize,
            isDirectory: false,
            dateCreated: attrs[.creationDate] as? Date,
            dateModified: attrs[.modificationDate] as? Date
        ))
    }

    private var allPaths: [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Library/Developer/Xcode/DerivedData",
            home + "/Library/Developer/Xcode/Archives",
            home + "/Library/Developer/Xcode/iOS DeviceSupport",
            home + "/Library/Developer/Xcode/watchOS DeviceSupport",
            home + "/Library/Developer/Xcode/DocumentationCache"
        ]
    }

    private func directorySize(_ url: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fm.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
}
