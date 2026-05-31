import Foundation

extension FileManager {
    static var freeDiskSpace: Int64 {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let path = paths.first,
              let attrs = try? `default`.attributesOfFileSystem(forPath: path) else { return 0 }
        return (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }

    static var totalDiskSpace: Int64 {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let path = paths.first,
              let attrs = try? `default`.attributesOfFileSystem(forPath: path) else { return 0 }
        return (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
    }

    static var usedDiskSpace: Int64 {
        totalDiskSpace - freeDiskSpace
    }
}
