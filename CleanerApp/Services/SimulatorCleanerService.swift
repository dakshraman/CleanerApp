import Foundation

final class SimulatorCleanerService: CleanupService {
    private var simulatorDir: URL? {
        let home = NSHomeDirectory()
        let path = home + "/Library/Developer/CoreSimulator"
        return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }

    func scan() async -> ScanResult {
        let start = Date()
        var items: [ScannedItem] = []
        let fm = FileManager.default

        guard let simDir = simulatorDir else {
            return ScanResult(category: .iosSimulator, items: [], totalSize: 0, duration: Date().timeIntervalSince(start))
        }

        scanCaches(simDir, fm: fm, items: &items)
        scanDevices(simDir, fm: fm, items: &items)

        items.sort { $0.size > $1.size }
        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .iosSimulator, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func scanCaches(_ simDir: URL, fm: FileManager, items: inout [ScannedItem]) {
        let cachesDir = simDir.appendingPathComponent("Caches")
        guard let contents = try? fm.contentsOfDirectory(
            at: cachesDir,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in contents {
            if Task.isCancelled { break }
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            let attrs = try? fm.attributesOfItem(atPath: item.path)
            let size = isDir.boolValue ? directorySize(item, fm: fm) : ((attrs?[.size] as? Int64) ?? 0)

            guard size > 0 else { continue }
            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: isDir.boolValue,
                dateCreated: attrs?[.creationDate] as? Date,
                dateModified: attrs?[.modificationDate] as? Date
            ))
        }
    }

    private func scanDevices(_ simDir: URL, fm: FileManager, items: inout [ScannedItem]) {
        let devicesPath = simDir.appendingPathComponent("Devices")
        guard let devices = try? fm.contentsOfDirectory(
            at: devicesPath,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for device in devices {
            if Task.isCancelled { break }
            let size = directorySize(device, fm: fm)
            guard size > 10 * 1024 * 1024 else { continue } // Only list simulator devices taking over 10MB

            let attrs = try? fm.attributesOfItem(atPath: device.path)
            // Try reading device plist to get device name
            let devicePlist = device.appendingPathComponent("device.plist")
            var deviceName = device.lastPathComponent
            if let dict = NSDictionary(contentsOf: devicePlist),
               let name = dict["name"] as? String {
                deviceName = "\(name) (\(device.lastPathComponent.prefix(8)))"
            }

            items.append(ScannedItem(
                url: device,
                size: size,
                isDirectory: true,
                dateCreated: attrs?[.creationDate] as? Date,
                dateModified: attrs?[.modificationDate] as? Date,
                groupTag: deviceName
            ))
        }
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
