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

        let total = items.reduce(0) { $0 + $1.size }
        return ScanResult(category: .iosSimulator, items: items, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func scanCaches(_ simDir: URL, fm: FileManager, items: inout [ScannedItem]) {
        let cachesDir = simDir.appendingPathComponent("Caches")
        guard let contents = try? fm.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey], options: []) else { return }
        for item in contents {
            guard let attrs = try? fm.attributesOfItem(atPath: item.path),
                  let size = attrs[.size] as? Int64 else { continue }
            items.append(ScannedItem(
                url: item,
                size: size,
                isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
                dateCreated: attrs[.creationDate] as? Date,
                dateModified: attrs[.modificationDate] as? Date
            ))
        }
    }

    private func scanDevices(_ simDir: URL, fm: FileManager, items: inout [ScannedItem]) {
        let devicesPath = simDir.appendingPathComponent("Devices")
        guard let devices = try? fm.contentsOfDirectory(at: devicesPath, includingPropertiesForKeys: nil, options: []) else { return }
        for device in devices {
            let dataDir = device.appendingPathComponent("data")
            guard fm.fileExists(atPath: dataDir.path),
                  let enumerator = fm.enumerator(at: dataDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            while let fileURL = enumerator.nextObject() as? URL {
                guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                      let size = attrs[.size] as? Int64,
                      size > 0 else { continue }
                items.append(ScannedItem(
                    url: fileURL,
                    size: size,
                    isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
                    dateCreated: attrs[.creationDate] as? Date,
                    dateModified: attrs[.modificationDate] as? Date
                ))
            }
        }
    }
}
