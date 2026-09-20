import Foundation
import CryptoKit

final class DuplicateFileService: CleanupService {
    private let scanPaths: [String] = {
        let home = NSHomeDirectory()
        return [
            home + "/Downloads",
            home + "/Documents",
            home + "/Desktop"
        ]
    }()

    func scan() async -> ScanResult {
        let start = Date()
        var sizeHash: [Int64: [URL]] = [:]
        let fm = FileManager.default

        // Step 1: Scan and group by file size
        for path in scanPaths {
            if Task.isCancelled { break }
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path),
                  let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isPackageKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                      let fileSize = attrs[.size] as? Int64,
                      fileSize >= 1024, // Ignore zero-byte or tiny files
                      attrs[.type] as? FileAttributeType == .typeRegular else { continue }
                sizeHash[fileSize, default: []].append(fileURL)
            }
        }

        var duplicates: [ScannedItem] = []

        // Step 2 & 3: Filter candidates by partial hash, then full hash
        for (size, urls) in sizeHash where urls.count > 1 {
            if Task.isCancelled { break }

            // Step 2: Partial Header Hash (first 16 KB)
            var partialHashGroups: [String: [URL]] = [:]
            for url in urls {
                if let partialHash = try? partialHeaderHash(at: url) {
                    partialHashGroups[partialHash, default: []].append(url)
                }
            }

            // Step 3: Full SHA-256 Hash for remaining candidates
            for (_, candidateURLs) in partialHashGroups where candidateURLs.count > 1 {
                if Task.isCancelled { break }
                var fullHashGroups: [String: [URL]] = [:]
                for url in candidateURLs {
                    if let hash = try? fullSha256OfFile(at: url) {
                        fullHashGroups[hash, default: []].append(url)
                    }
                }

                for (hash, group) in fullHashGroups where group.count > 1 {
                    // Sort group by modification date so the earliest is considered original
                    let sortedByDate = group.sorted { u1, u2 in
                        let d1 = (try? fm.attributesOfItem(atPath: u1.path)[.modificationDate] as? Date) ?? .distantPast
                        let d2 = (try? fm.attributesOfItem(atPath: u2.path)[.modificationDate] as? Date) ?? .distantPast
                        return d1 < d2
                    }

                    // Add all copies in the duplicate set (keeping the group tag for UI presentation)
                    for (index, url) in sortedByDate.enumerated() {
                        let attrs = (try? fm.attributesOfItem(atPath: url.path)) ?? [:]
                        // We attach the duplicate group identifier
                        let item = ScannedItem(
                            url: url,
                            size: size,
                            isDirectory: false,
                            dateCreated: attrs[.creationDate] as? Date,
                            dateModified: attrs[.modificationDate] as? Date,
                            groupTag: hash
                        )
                        // All except the first are duplicates candidate for cleaning
                        if index > 0 {
                            duplicates.append(item)
                        }
                    }
                }
            }
        }

        let total = duplicates.reduce(0) { $0 + $1.size }
        return ScanResult(category: .duplicateFiles, items: duplicates, totalSize: total, duration: Date().timeIntervalSince(start))
    }

    private func partialHeaderHash(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let headerData = handle.readData(ofLength: 16_384)
        let digest = SHA256.hash(data: headerData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func fullSha256OfFile(at url: URL) throws -> String {
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
