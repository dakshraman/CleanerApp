import Foundation

final class AppUninstallerService: Sendable {
    func scanInstalledApps() async -> [InstalledAppInfo] {
        let fm = FileManager.default
        let appDirs = [
            "/Applications",
            "/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]

        var apps: [InstalledAppInfo] = []

        for dir in appDirs {
            if Task.isCancelled { break }
            let url = URL(fileURLWithPath: dir)
            guard fm.fileExists(atPath: dir),
                  let contents = try? fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                  ) else { continue }

            for appURL in contents where appURL.pathExtension == "app" {
                if Task.isCancelled { break }
                let bundleInfoURL = appURL.appendingPathComponent("Contents/Info.plist")
                guard let info = NSDictionary(contentsOf: bundleInfoURL) else { continue }

                let bundleID = (info["CFBundleIdentifier"] as? String) ?? appURL.deletingPathExtension().lastPathComponent
                let name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? appURL.deletingPathExtension().lastPathComponent
                let version = (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String) ?? "1.0"

                // Calculate app bundle size
                let appSize = directorySize(appURL, fm: fm)

                // Resolve related supporting files (caches, containers, launch agents, pref panes)
                let related = resolveAssociatedFiles(for: bundleID, appName: name, fm: fm)
                let supportingSize = related.reduce(Int64(0)) { total, u in
                    var isDir: ObjCBool = false
                    fm.fileExists(atPath: u.path, isDirectory: &isDir)
                    let uSize: Int64 = isDir.boolValue ? directorySize(u, fm: fm) : ((try? fm.attributesOfItem(atPath: u.path)[.size] as? Int64) ?? 0)
                    return total + uSize
                }

                let lastModified = (try? fm.attributesOfItem(atPath: appURL.path)[.modificationDate] as? Date)

                apps.append(InstalledAppInfo(
                    name: name,
                    bundleID: bundleID,
                    version: version,
                    appURL: appURL,
                    totalSize: appSize + supportingSize,
                    appBundleSize: appSize,
                    supportingFilesSize: supportingSize,
                    relatedURLs: related,
                    lastUsedDate: lastModified
                ))
            }
        }

        return apps.sorted { $0.totalSize > $1.totalSize }
    }

    private func resolveAssociatedFiles(for bundleID: String, appName: String, fm: FileManager) -> [URL] {
        let home = NSHomeDirectory()
        var urls: [URL] = []

        let candidatePaths = [
            // Application Support & Data
            "\(home)/Library/Application Support/\(bundleID)",
            "\(home)/Library/Application Support/\(appName)",
            "\(home)/Library/Caches/\(bundleID)",
            "\(home)/Library/Caches/\(appName)",
            "\(home)/Library/Preferences/\(bundleID).plist",
            "\(home)/Library/Saved Application State/\(bundleID).savedState",
            "\(home)/Library/Containers/\(bundleID)",
            "\(home)/Library/Group Containers/\(bundleID)",
            "\(home)/Library/HTTPStorages/\(bundleID)",
            "\(home)/Library/WebKit/\(bundleID)",
            "\(home)/Library/SyncedPreferences/\(bundleID).plist",

            // Login items, Launch Agents & Background Daemons
            "\(home)/Library/LaunchAgents/\(bundleID).plist",
            "\(home)/Library/LaunchAgents/\(appName).plist",
            "/Library/LaunchAgents/\(bundleID).plist",
            "/Library/LaunchDaemons/\(bundleID).plist",

            // Preference Panes & Plugins
            "\(home)/Library/PreferencePanes/\(appName).prefPane",
            "/Library/PreferencePanes/\(appName).prefPane",
            "\(home)/Library/QuickLook/\(appName).qlgenerator",
            "\(home)/Library/Services/\(appName).workflow"
        ]

        for p in candidatePaths {
            if fm.fileExists(atPath: p) {
                urls.append(URL(fileURLWithPath: p))
            }
        }

        return urls
    }

    func uninstall(app: InstalledAppInfo, useTrash: Bool) -> (success: Bool, freed: Int64, errors: [String]) {
        let allURLs = [app.appURL] + app.relatedURLs
        var freed: Int64 = 0
        var errors: [String] = []
        let fm = FileManager.default

        // Unload launch agents if any
        #if os(macOS)
        for u in app.relatedURLs where u.pathExtension == "plist" && u.path.contains("Launch") {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["bootout", "gui/\(getuid())/\(app.bundleID)"]
            try? task.run()
        }
        #endif

        for u in allURLs {
            do {
                if useTrash {
                    var resulting: NSURL?
                    try fm.trashItem(at: u, resultingItemURL: &resulting)
                } else {
                    try fm.removeItem(at: u)
                }
                freed += app.totalSize
            } catch {
                errors.append("\(u.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return (errors.isEmpty, freed, errors)
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
