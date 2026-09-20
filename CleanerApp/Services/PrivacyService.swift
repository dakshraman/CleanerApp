import Foundation

final class PrivacyService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default
        let home = NSHomeDirectory()

        let privacyPaths: [(name: String, path: String, icon: String)] = [
            ("Safari History & Cache", "\(home)/Library/Safari/History.db", "safari"),
            ("Safari Tracking Cookies", "\(home)/Library/Cookies/Cookies.binarycookies", "safari"),
            ("Google Chrome History", "\(home)/Library/Application Support/Google/Chrome/Default/History", "globe"),
            ("Google Chrome Cookies", "\(home)/Library/Application Support/Google/Chrome/Default/Cookies", "globe"),
            ("Google Chrome Cache", "\(home)/Library/Caches/Google/Chrome/Default/Cache", "globe"),
            ("Microsoft Edge History", "\(home)/Library/Application Support/Microsoft Edge/Default/History", "globe"),
            ("Brave Browser Cache", "\(home)/Library/Caches/BraveSoftware/Brave-Browser/Default/Cache", "globe"),
            ("Firefox Profiles Cache", "\(home)/Library/Caches/Firefox/Profiles", "globe"),
            ("Recent Documents History", "\(home)/Library/Application Support/com.apple.sharedfilelist", "doc.text")
        ]

        for entry in privacyPaths {
            if Task.isCancelled { break }
            let url = URL(fileURLWithPath: entry.path)
            guard fm.fileExists(atPath: entry.path) else { continue }

            var isDir: ObjCBool = false
            fm.fileExists(atPath: entry.path, isDirectory: &isDir)

            let attrs = try? fm.attributesOfItem(atPath: entry.path)
            let size = isDir.boolValue ? directorySize(url, fm: fm) : ((attrs?[.size] as? Int64) ?? 0)
            guard size > 0 else { continue }

            items.append(ScannedItem(
                url: url,
                size: size,
                isDirectory: isDir.boolValue,
                dateCreated: attrs?[.creationDate] as? Date,
                dateModified: attrs?[.modificationDate] as? Date,
                groupTag: entry.name
            ))
        }

        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .appLogs, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
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
