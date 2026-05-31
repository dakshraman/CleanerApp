import SwiftUI

enum CleanupCategory: String, CaseIterable, Identifiable {
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
        case .malware: return "ant"
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
        case .appRemnants: return .brown
        }
    }

    var description: String {
        switch self {
        case .systemCache: return "Clear app and system cache files"
        case .tempFiles: return "Remove temporary files created by apps"
        case .duplicateFiles: return "Find and remove duplicate files"
        case .largeFiles: return "Find files taking up significant space"
        case .appLogs: return "Remove logs, crash reports, and diagnostics"
        case .iosSimulator: return "Clean simulator devices, caches, and data"
        case .downloads: return "Review and clean your Downloads folder"
        case .xcodeDerived: return "Remove derived data, archives, and build products"
        case .malware: return "Detect and remove adware, suspicious launch agents, and browser hijackers"
        case .appRemnants: return "Clean leftover app data from uninstalled applications"
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

enum PlatformSupport: String {
    case macOS = "macOS"
    case iOS = "iOS"
}
