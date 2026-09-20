import SwiftUI

// MARK: - Navigation Item
enum NavigationTab: String, CaseIterable, Identifiable, Sendable {
    case smartCare = "Smart Care"
    case systemJunk = "System Junk"
    case mailAttachments = "Mail & Downloads"
    case trashBins = "Trash Bins"
    case malwareRemoval = "Malware Removal"
    case privacy = "Privacy"
    case optimization = "Optimization"
    case maintenance = "Maintenance"
    case uninstaller = "Uninstaller"
    case appRemnants = "Leftovers"
    case spaceLens = "Space Lens"
    case largeAndOld = "Large & Old Files"
    case duplicates = "Duplicates"

    var id: String { rawValue }

    var sectionTitle: String {
        switch self {
        case .smartCare: return "SMART CARE"
        case .systemJunk, .mailAttachments, .trashBins: return "CLEANUP"
        case .malwareRemoval, .privacy: return "PROTECTION"
        case .optimization, .maintenance: return "SPEED"
        case .uninstaller, .appRemnants: return "APPLICATIONS"
        case .spaceLens, .largeAndOld, .duplicates: return "FILES"
        }
    }

    var iconName: String {
        switch self {
        case .smartCare: return "sparkles"
        case .systemJunk: return "archivebox.fill"
        case .mailAttachments: return "arrow.down.circle.fill"
        case .trashBins: return "trash.fill"
        case .malwareRemoval: return "shield.lefthalf.filled"
        case .privacy: return "hand.raised.fill"
        case .optimization: return "bolt.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .uninstaller: return "xmark.bin.fill"
        case .appRemnants: return "tray.full.fill"
        case .spaceLens: return "circle.grid.2x2.fill"
        case .largeAndOld: return "externaldrive.fill"
        case .duplicates: return "doc.on.doc.fill"
        }
    }

    var gradient: [Color] {
        switch self {
        case .smartCare: return [.cyan, .blue, .purple]
        case .systemJunk: return [.blue, .teal]
        case .mailAttachments: return [.teal, .mint]
        case .trashBins: return [.gray, .secondary]
        case .malwareRemoval: return [.pink, .purple]
        case .privacy: return [.indigo, .purple]
        case .optimization: return [.orange, .yellow]
        case .maintenance: return [.green, .mint]
        case .uninstaller: return [.red, .pink]
        case .appRemnants: return [.purple, .indigo]
        case .spaceLens: return [.cyan, .indigo]
        case .largeAndOld: return [.orange, .red]
        case .duplicates: return [.purple, .pink]
        }
    }

    var subtitle: String {
        switch self {
        case .smartCare: return "One-click complete Mac health & cleanup"
        case .systemJunk: return "Clear cache files, system logs, and temporary data"
        case .mailAttachments: return "Remove downloaded attachments and old installers"
        case .trashBins: return "Empty primary and external disk Trash bins safely"
        case .malwareRemoval: return "Scan for adware, suspicious daemons, and vulnerabilities"
        case .privacy: return "Wipe browser histories, tracking cookies, and traces"
        case .optimization: return "Manage login items and high-energy background processes"
        case .maintenance: return "Purge RAM, flush DNS, and repair disk permissions"
        case .uninstaller: return "Completely uninstall apps and all supporting files"
        case .appRemnants: return "Find and remove leftovers from previously deleted apps"
        case .spaceLens: return "Visual breakdown of largest folders and disk usage"
        case .largeAndOld: return "Isolate files over 100MB and forgotten archives"
        case .duplicates: return "Find and remove identical duplicate files"
        }
    }
}

// MARK: - Installed App Model
struct InstalledAppInfo: Identifiable, Sendable, Hashable {
    let id: UUID
    let name: String
    let bundleID: String
    let version: String
    let appURL: URL
    let totalSize: Int64
    let appBundleSize: Int64
    let supportingFilesSize: Int64
    let relatedURLs: [URL]
    let lastUsedDate: Date?

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        bundleID: String,
        version: String,
        appURL: URL,
        totalSize: Int64,
        appBundleSize: Int64,
        supportingFilesSize: Int64,
        relatedURLs: [URL],
        lastUsedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.appURL = appURL
        self.totalSize = totalSize
        self.appBundleSize = appBundleSize
        self.supportingFilesSize = supportingFilesSize
        self.relatedURLs = relatedURLs
        self.lastUsedDate = lastUsedDate
    }

    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledAppInfo, rhs: InstalledAppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Maintenance Item
struct MaintenanceTaskItem: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: String
    var isRunning: Bool
    var isCompleted: Bool
    var statusMessage: String?

    nonisolated init(
        id: String,
        title: String,
        description: String,
        icon: String,
        category: String,
        isRunning: Bool = false,
        isCompleted: Bool = false,
        statusMessage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.category = category
        self.isRunning = isRunning
        self.isCompleted = isCompleted
        self.statusMessage = statusMessage
    }
}

// MARK: - Privacy Item
struct PrivacyItem: Identifiable, Sendable {
    let id: UUID
    let appName: String
    let appIcon: String
    let itemType: String
    let description: String
    let path: URL
    let estimatedSize: Int64

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedSize)
    }
}
