import Foundation

final class AppRemnantsService: CleanupService {
    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        let installedBundleIDs = collectInstalledBundleIDs(fm: fm)

        scanDirectory(
            URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support"),
            installedIDs: installedBundleIDs,
            fm: fm,
            items: &items
        )
        scanDirectory(
            URL(fileURLWithPath: NSHomeDirectory() + "/Library/Caches"),
            installedIDs: installedBundleIDs,
            fm: fm,
            items: &items
        )
        scanPreferences(installedIDs: installedBundleIDs, fm: fm, items: &items)
        scanSavedState(installedIDs: installedBundleIDs, fm: fm, items: &items)
        scanContainers(installedIDs: installedBundleIDs, fm: fm, items: &items)

        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .appRemnants, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func collectInstalledBundleIDs(fm: FileManager) -> Set<String> {
        var ids = Set<String>()
        let appDirs = ["/Applications", NSHomeDirectory() + "/Applications"]

        for dir in appDirs {
            let url = URL(fileURLWithPath: dir)
            guard fm.fileExists(atPath: dir),
                  let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for app in contents where app.pathExtension == "app" {
                let bundleURL = app.appendingPathComponent("Contents/Info.plist")
                guard let info = NSDictionary(contentsOf: bundleURL),
                      let bundleID = info["CFBundleIdentifier"] as? String else { continue }
                ids.insert(bundleID)

                if let name = info["CFBundleName"] as? String {
                    ids.insert(name)
                }
                if let displayName = info["CFBundleDisplayName"] as? String {
                    ids.insert(displayName)
                }
                if let exec = info["CFBundleExecutable"] as? String {
                    ids.insert(exec)
                }
            }
        }

        return ids
    }

    private func scanDirectory(_ dir: URL, installedIDs: Set<String>, fm: FileManager, items: inout [ScannedItem]) {
        guard fm.fileExists(atPath: dir.path),
              let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }

        for item in contents {
            let name = item.lastPathComponent
                .replacingOccurrences(of: ".plist", with: "")
                .replacingOccurrences(of: ".savedState", with: "")
                .replacingOccurrences(of: ".com.apple.", with: "com.apple.")

            let relevant = installedIDs.contains { id in
                name.lowercased().contains(id.lowercased()) ||
                id.lowercased().contains(name.lowercased())
            }
            if relevant { continue }
            if name.hasPrefix("com.apple.") || name == ".DS_Store" { continue }

            let size: Int64 = {
                guard let attrs = try? fm.attributesOfItem(atPath: item.path),
                      let s = attrs[.size] as? Int64 else { return 0 }
                if s == 0, (attrs[.type] as? FileAttributeType) == .typeDirectory {
                    return directorySize(item, fm: fm)
                }
                return s
            }()
            guard size > 0 else { continue }

            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: true,
                dateCreated: nil,
                dateModified: nil
            ))
        }
    }

    private func scanPreferences(installedIDs: Set<String>, fm: FileManager, items: inout [ScannedItem]) {
        let prefsDir = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Preferences")
        guard fm.fileExists(atPath: prefsDir.path),
              let contents = try? fm.contentsOfDirectory(at: prefsDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return }

        for item in contents {
            let name = item.lastPathComponent
                .replacingOccurrences(of: ".plist", with: "")
            if name.hasPrefix("com.apple.") { continue }

            let relevant = installedIDs.contains { id in
                name.lowercased().contains(id.lowercased()) ||
                id.lowercased().contains(name.lowercased())
            }
            if relevant { continue }

            guard let attrs = try? fm.attributesOfItem(atPath: item.path),
                  let size = attrs[.size] as? Int64,
                  size > 0 else { continue }
            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: false,
                dateCreated: attrs[.creationDate] as? Date,
                dateModified: attrs[.modificationDate] as? Date
            ))
        }
    }

    private func scanSavedState(installedIDs: Set<String>, fm: FileManager, items: inout [ScannedItem]) {
        let stateDir = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Saved Application State")
        guard fm.fileExists(atPath: stateDir.path),
              let contents = try? fm.contentsOfDirectory(at: stateDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return }

        for item in contents {
            let name = item.lastPathComponent
                .replacingOccurrences(of: ".savedState", with: "")
            if name.hasPrefix("com.apple.") { continue }

            let relevant = installedIDs.contains { id in
                name.lowercased().contains(id.lowercased()) ||
                id.lowercased().contains(name.lowercased())
            }
            if relevant { continue }

            let size = directorySize(item, fm: fm)
            guard size > 0 else { continue }
            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: true,
                dateCreated: nil,
                dateModified: nil
            ))
        }
    }

    private func scanContainers(installedIDs: Set<String>, fm: FileManager, items: inout [ScannedItem]) {
        let containersDir = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Containers")
        guard fm.fileExists(atPath: containersDir.path),
              let contents = try? fm.contentsOfDirectory(at: containersDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return }

        for item in contents {
            let name = item.lastPathComponent
            if name.hasPrefix("com.apple.") { continue }

            let relevant = installedIDs.contains { id in
                name.lowercased().contains(id.lowercased()) ||
                id.lowercased().contains(name.lowercased())
            }
            if relevant { continue }

            let size = directorySize(item, fm: fm)
            guard size > 0 else { continue }
            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: true,
                dateCreated: nil,
                dateModified: nil
            ))
        }
    }

    private func directorySize(_ url: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let attrs = try? fm.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
}
