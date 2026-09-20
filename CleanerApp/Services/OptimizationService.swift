import Foundation

enum StartupItemType: String, Sendable, CaseIterable {
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"
    case preferencePane = "Preference Pane"
    case quickLookPlugin = "QuickLook Plugin"
    case servicePlugin = "Services Menu Item"

    var icon: String {
        switch self {
        case .launchAgent: return "bolt.horizontal.circle.fill"
        case .launchDaemon: return "gearshape.2.fill"
        case .preferencePane: return "switch.2"
        case .quickLookPlugin: return "eye.fill"
        case .servicePlugin: return "menucard.fill"
        }
    }
}

struct StartupItem: Identifiable, Sendable {
    let id: UUID
    let name: String
    let fileURL: URL
    let targetExecutablePath: String?
    let itemType: StartupItemType
    let isBroken: Bool
    let statusDescription: String

    var formattedType: String {
        itemType.rawValue
    }
}

final class OptimizationService: Sendable {
    func scanStartupItems() async -> [StartupItem] {
        let fm = FileManager.default
        let home = NSHomeDirectory()

        var items: [StartupItem] = []

        // 1. User Launch Agents
        let userAgentsDir = URL(fileURLWithPath: "\(home)/Library/LaunchAgents")
        items.append(contentsOf: scanLaunchDirectory(userAgentsDir, type: .launchAgent, fm: fm))

        // 2. System Launch Agents
        let systemAgentsDir = URL(fileURLWithPath: "/Library/LaunchAgents")
        items.append(contentsOf: scanLaunchDirectory(systemAgentsDir, type: .launchAgent, fm: fm))

        // 3. System Launch Daemons
        let systemDaemonsDir = URL(fileURLWithPath: "/Library/LaunchDaemons")
        items.append(contentsOf: scanLaunchDirectory(systemDaemonsDir, type: .launchDaemon, fm: fm))

        // 4. Preference Panes
        let prefPanes = [
            "\(home)/Library/PreferencePanes",
            "/Library/PreferencePanes"
        ]
        for dir in prefPanes {
            items.append(contentsOf: scanPluginsDirectory(URL(fileURLWithPath: dir), type: .preferencePane, fm: fm))
        }

        // 5. QuickLook & Services
        let quickLookDirs = [
            "\(home)/Library/QuickLook",
            "/Library/QuickLook"
        ]
        for dir in quickLookDirs {
            items.append(contentsOf: scanPluginsDirectory(URL(fileURLWithPath: dir), type: .quickLookPlugin, fm: fm))
        }

        let servicesDir = URL(fileURLWithPath: "\(home)/Library/Services")
        items.append(contentsOf: scanPluginsDirectory(servicesDir, type: .servicePlugin, fm: fm))

        // Sort: Broken items first, then by name
        return items.sorted {
            if $0.isBroken != $1.isBroken {
                return $0.isBroken && !$1.isBroken
            }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    private func scanLaunchDirectory(_ dirURL: URL, type: StartupItemType, fm: FileManager) -> [StartupItem] {
        guard fm.fileExists(atPath: dirURL.path),
              let files = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        var results: [StartupItem] = []

        for file in files where file.pathExtension == "plist" {
            guard let dict = NSDictionary(contentsOf: file) else { continue }

            var execPath: String?
            if let prog = dict["Program"] as? String {
                execPath = prog
            } else if let args = dict["ProgramArguments"] as? [String], let first = args.first {
                execPath = first
            }

            let name = (dict["Label"] as? String) ?? file.deletingPathExtension().lastPathComponent

            var isBroken = false
            var statusDesc = "Active Startup Item"

            if let target = execPath {
                if !fm.fileExists(atPath: target) {
                    isBroken = true
                    statusDesc = "Broken (Uninstalled app leftover - target not found: \(target))"
                } else {
                    statusDesc = "Points to \(target)"
                }
            } else {
                // Check if bundle or binary target is missing
                isBroken = false
                statusDesc = "Configured Launch Agent"
            }

            results.append(StartupItem(
                id: UUID(),
                name: name,
                fileURL: file,
                targetExecutablePath: execPath,
                itemType: type,
                isBroken: isBroken,
                statusDescription: statusDesc
            ))
        }

        return results
    }

    private func scanPluginsDirectory(_ dirURL: URL, type: StartupItemType, fm: FileManager) -> [StartupItem] {
        guard fm.fileExists(atPath: dirURL.path),
              let files = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        var results: [StartupItem] = []

        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            results.append(StartupItem(
                id: UUID(),
                name: name,
                fileURL: file,
                targetExecutablePath: file.path,
                itemType: type,
                isBroken: false,
                statusDescription: "Installed extension in \(file.deletingLastPathComponent().lastPathComponent)"
            ))
        }

        return results
    }

    func removeStartupItem(_ item: StartupItem) -> (success: Bool, message: String) {
        let fm = FileManager.default
        do {
            #if os(macOS)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["bootout", "gui/\(getuid())/\(item.name)"]
            try? task.run()
            #endif

            try fm.removeItem(at: item.fileURL)
            return (true, "Removed \(item.name)")
        } catch {
            return (false, "Could not remove: \(error.localizedDescription)")
        }
    }
}
