import Foundation

final class XcodeCleanerService: CleanupService {
    let includeArchives: Bool

    init(includeArchives: Bool = false) {
        self.includeArchives = includeArchives
    }

    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        for path in allPaths {
            if Task.isCancelled { break }
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

        items.sort { $0.size > $1.size }
        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .xcodeDerived, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func scanDirectory(_ url: URL, fm: FileManager, items: inout [ScannedItem]) {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in contents {
            if Task.isCancelled { break }
            guard let attrs = try? fm.attributesOfItem(atPath: item.path) else { continue }
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)

            let fileSize: Int64 = isDir.boolValue ? directorySize(item, fm: fm) : ((attrs[.size] as? Int64) ?? 0)
            guard fileSize > 0 else { continue }

            items.append(ScannedItem(
                url: item,
                size: fileSize,
                isDirectory: isDir.boolValue,
                dateCreated: attrs[.creationDate] as? Date,
                dateModified: attrs[.modificationDate] as? Date
            ))
        }
    }

    private func addFile(_ url: URL, fm: FileManager, items: inout [ScannedItem]) {
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? Int64,
              fileSize > 0 else { return }
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
        var paths = [
            home + "/Library/Developer/Xcode/DerivedData",
            home + "/Library/Developer/Xcode/iOS DeviceSupport",
            home + "/Library/Developer/Xcode/watchOS DeviceSupport",
            home + "/Library/Developer/Xcode/DocumentationCache",
            home + "/Library/Developer/Xcode/UserData/Previews/Simulator Devices",
            home + "/Library/Caches/com.apple.dt.Xcode"
        ]

        if includeArchives {
            paths.append(home + "/Library/Developer/Xcode/Archives")
        }

        return paths
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
