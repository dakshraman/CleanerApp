import Foundation

final class AppRemnantsService: CleanupService {
    private let whitelistedKeywords: Set<String> = [
        "docker", "homebrew", "git", "cursor", "vscode", "code", "sublime",
        "iterm", "iterm2", "terminal", "jetbrains", "intellij", "pycharm",
        "webstorm", "clion", "goland", "rustrover", "steam", "discord",
        "slack", "zoom", "spotify", "telegram", "whatsapp", "signal",
        "dropbox", "1password", "bitwarden", "notion", "obsidian", "raycast",
        "alfred", "figma", "sketch", "postman", "insomnia", "tableplus",
        "dbeaver", "sequel", "proxyman", "wireshark", "parallels", "utm",
        "virtualbox", "gnupg", "ssh", "node", "npm", "pnpm", "yarn",
        "pip", "cargo", "rust", "go", "flutter", "android", "gradle",
        "mvn", "zsh", "bash", "fish", "tmux", "neovim", "vim", "emacs",
        "xcode", "apple", "icloud", "cloudkit", "safari", "finder", "system",
        "quicklook", "spotlight", "google", "microsoft", "adobe", "brave"
    ]

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
        scanPreferences(installedIDs: installedBundleIDs, fm: fm, items: &items)
        scanSavedState(installedIDs: installedBundleIDs, fm: fm, items: &items)

        items.sort { $0.size > $1.size }
        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .appRemnants, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func collectInstalledBundleIDs(fm: FileManager) -> Set<String> {
        var ids = Set<String>()
        let appDirs = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
            NSHomeDirectory() + "/Applications"
        ]

        for dir in appDirs {
            let url = URL(fileURLWithPath: dir)
            guard fm.fileExists(atPath: dir),
                  let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for app in contents where app.pathExtension == "app" {
                let bundleURL = app.appendingPathComponent("Contents/Info.plist")
                guard let info = NSDictionary(contentsOf: bundleURL) else { continue }

                if let bundleID = info["CFBundleIdentifier"] as? String {
                    ids.insert(bundleID.lowercased())
                }
                if let name = info["CFBundleName"] as? String {
                    ids.insert(name.lowercased())
                }
                if let displayName = info["CFBundleDisplayName"] as? String {
                    ids.insert(displayName.lowercased())
                }
                if let exec = info["CFBundleExecutable"] as? String {
                    ids.insert(exec.lowercased())
                }
                ids.insert(app.deletingPathExtension().lastPathComponent.lowercased())
            }
        }

        return ids
    }

    private func isSafeToFlagAsRemnant(name: String, installedIDs: Set<String>) -> Bool {
        let lowerName = name.lowercased()

        // Ignore Apple system directories and invisible files
        if lowerName.hasPrefix("com.apple.") || lowerName.hasPrefix(".") || lowerName == "system" {
            return false
        }

        // Whitelist common CLI, developer, and popular tools
        for kw in whitelistedKeywords {
            if lowerName.contains(kw) {
                return false
            }
        }

        // Check if matching any installed application
        for id in installedIDs {
            if !id.isEmpty && (lowerName.contains(id) || id.contains(lowerName)) {
                return false
            }
        }

        return true
    }

    private func scanDirectory(_ dir: URL, installedIDs: Set<String>, fm: FileManager, items: inout [ScannedItem]) {
        guard fm.fileExists(atPath: dir.path),
              let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        for item in contents {
            if Task.isCancelled { break }
            let rawName = item.lastPathComponent
            let cleanName = rawName
                .replacingOccurrences(of: ".plist", with: "")
                .replacingOccurrences(of: ".savedState", with: "")

            guard isSafeToFlagAsRemnant(name: cleanName, installedIDs: installedIDs) else { continue }

            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            let size = isDir.boolValue ? directorySize(item, fm: fm) : ((try? fm.attributesOfItem(atPath: item.path)[.size] as? Int64) ?? 0)

            guard size >= 1024 else { continue } // Only report if size is notable

            let attrs = try? fm.attributesOfItem(atPath: item.path)
            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: isDir.boolValue,
                dateCreated: attrs?[.creationDate] as? Date,
                dateModified: attrs?[.modificationDate] as? Date
            ))
        }
    }

    private func scanPreferences(installedIDs: Set<String>, fm: FileManager, items: inout [ScannedItem]) {
        let prefsDir = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Preferences")
        guard fm.fileExists(atPath: prefsDir.path),
              let contents = try? fm.contentsOfDirectory(at: prefsDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return }

        for item in contents {
            if Task.isCancelled { break }
            let name = item.lastPathComponent.replacingOccurrences(of: ".plist", with: "")
            guard isSafeToFlagAsRemnant(name: name, installedIDs: installedIDs) else { continue }

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
            if Task.isCancelled { break }
            let name = item.lastPathComponent.replacingOccurrences(of: ".savedState", with: "")
            guard isSafeToFlagAsRemnant(name: name, installedIDs: installedIDs) else { continue }

            let size = directorySize(item, fm: fm)
            guard size > 0 else { continue }

            let attrs = try? fm.attributesOfItem(atPath: item.path)
            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: true,
                dateCreated: attrs?[.creationDate] as? Date,
                dateModified: attrs?[.modificationDate] as? Date
            ))
        }
    }

    private func directorySize(_ url: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
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
