import Foundation
import CryptoKit

final class DuplicateFileService: CleanupService {
    private let scanPaths = [
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Documents",
        NSHomeDirectory() + "/Desktop"
    ]

    func scan() async -> ScanResult {
        let start = Date()
        var sizeHash: [Int64: [URL]] = [:]
        let fm = FileManager.default

        for path in scanPaths {
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path),
                  let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            while let fileURL = enumerator.nextObject() as? URL {
                guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                      let fileSize = attrs[.size] as? Int64,
                      fileSize > 0,
                      attrs[.type] as? FileAttributeType == .typeRegular else { continue }
                sizeHash[fileSize, default: []].append(fileURL)
            }
        }

        var duplicates: [ScannedItem] = []
        for (size, urls) in sizeHash where urls.count > 1 {
            var hashGroups: [String: [URL]] = [:]
            for url in urls {
                if let hash = try? sha256OfFile(at: url) {
                    hashGroups[hash, default: []].append(url)
                }
            }
            for (_, group) in hashGroups where group.count > 1 {
                for url in group.dropFirst() {
                    let attrs = (try? fm.attributesOfItem(atPath: url.path)) ?? [:]
                    duplicates.append(ScannedItem(
                        url: url,
                        size: size,
                        isDirectory: false,
                        dateCreated: attrs[.creationDate] as? Date,
                        dateModified: attrs[.modificationDate] as? Date
                    ))
                }
            }
        }

        let total = duplicates.reduce(0) { $0 + $1.size }
        return ScanResult(category: .duplicateFiles, items: duplicates, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func sha256OfFile(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1_048_576)
            if data.isEmpty { return false }
            hasher.update(data: data)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
