import SwiftUI

enum CleanupCategory: String, CaseIterable, Identifiable, Sendable {
    case systemCache = "System Cache"
    case tempFiles = "Temporary Files"
    case duplicateFiles = "Duplicate Files"
    case largeFiles = "Large & Old Files"
    case appLogs = "App Logs & Crash Reports"
    case iosSimulator = "iOS Simulator Data"
    case downloads = "Downloads"
    case xcodeDerived = "Xcode Derived Data"
    case malware = "Malware & Adware"
    case appRemnants = "App Remnants"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .systemCache: return "archivebox"
        case .tempFiles: return "trash"
        case .duplicateFiles: return "doc.on.doc"
        case .largeFiles: return "externaldrive"
        case .appLogs: return "doc.text.magnifyingglass"
        case .iosSimulator: return "iphone.gen2"
        case .downloads: return "arrow.down.circle"
        case .xcodeDerived: return "hammer"
        case .malware: return "shield.lefthalf.filled"
        case .appRemnants: return "tray.full"
        }
    }

    var tint: Color {
        switch self {
        case .systemCache: return .blue
        case .tempFiles: return .gray
        case .duplicateFiles: return .purple
        case .largeFiles: return .orange
        case .appLogs: return .yellow
        case .iosSimulator: return .teal
        case .downloads: return .green
        case .xcodeDerived: return .red
        case .malware: return .pink
        case .appRemnants: return .indigo
        }
    }

    var description: String {
        switch self {
        case .systemCache: return "App and system caches safe to clear"
        case .tempFiles: return "Temporary scratch and cache files"
        case .duplicateFiles: return "Identical duplicate files across folders"
        case .largeFiles: return "Individual files occupying significant disk space"
        case .appLogs: return "Old diagnostic logs and crash reports"
        case .iosSimulator: return "Simulator device caches and legacy runtimes"
        case .downloads: return "Downloaded installers and older archive files"
        case .xcodeDerived: return "DerivedData, device support, and build artifacts"
        case .malware: return "Adware signatures, suspicious launch agents, and browser hijackers"
        case .appRemnants: return "Leftover support folders from uninstalled applications"
        }
    }

    var defaultSelectItemsOnScan: Bool {
        switch self {
        case .largeFiles:
            // Large files are personal documents/media - user must explicitly pick which ones to remove!
            return false
        default:
            return true
        }
    }

    var platforms: [PlatformSupport] {
        switch self {
        case .iosSimulator, .xcodeDerived, .malware, .appRemnants:
            return [.macOS]
        default:
            return [.macOS, .iOS]
        }
    }
}

enum PlatformSupport: String, Sendable {
    case macOS = "macOS"
    case iOS = "iOS"
}
