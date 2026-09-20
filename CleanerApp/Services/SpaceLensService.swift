import Foundation
import SwiftUI

struct SpaceLensItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: URL
    let size: Int64
    let isDirectory: Bool
    let color: Color
    let icon: String

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

final class SpaceLensService: Sendable {
    func scanSpaceLens() async -> [SpaceLensItem] {
        let home = NSHomeDirectory()
        let fm = FileManager.default

        let targets: [(name: String, path: String, color: Color, icon: String)] = [
            ("Applications", "/Applications", .red, "app.fill"),
            ("Developer & Xcode", "\(home)/Library/Developer", .cyan, "hammer.fill"),
            ("Downloads", "\(home)/Downloads", .green, "arrow.down.circle.fill"),
            ("Documents", "\(home)/Documents", .blue, "doc.fill"),
            ("Caches & Data", "\(home)/Library/Caches", .purple, "archivebox.fill"),
            ("App Support", "\(home)/Library/Application Support", .indigo, "folder.badge.gearshape"),
            ("Movies & Video", "\(home)/Movies", .orange, "film.fill"),
            ("Music & Audio", "\(home)/Music", .pink, "music.note"),
            ("Pictures & Photos", "\(home)/Pictures", .yellow, "photo.fill"),
            ("Desktop", "\(home)/Desktop", .teal, "macbook")
        ]

        var results: [SpaceLensItem] = []

        for target in targets {
            if Task.isCancelled { break }
            let url = URL(fileURLWithPath: target.path)
            guard fm.fileExists(atPath: target.path) else { continue }
            var isDir: ObjCBool = false
            fm.fileExists(atPath: target.path, isDirectory: &isDir)

            let size = isDir.boolValue ? directorySize(url, fm: fm) : ((try? fm.attributesOfItem(atPath: target.path)[.size] as? Int64) ?? 0)
            guard size > 0 else { continue }

            results.append(SpaceLensItem(
                name: target.name,
                path: url,
                size: size,
                isDirectory: isDir.boolValue,
                color: target.color,
                icon: target.icon
            ))
        }

        return results.sorted { $0.size > $1.size }
    }

    private func directorySize(_ url: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
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
