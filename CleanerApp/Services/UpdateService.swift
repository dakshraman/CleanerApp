import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct AppReleaseInfo: Sendable, Decodable {
    public let tagName: String
    public let releaseNotes: String
    public let downloadURL: URL?
    public let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case releaseNotes = "body"
        case assets
        case publishedAt = "published_at"
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tagName = try container.decode(String.self, forKey: .tagName)
        self.releaseNotes = try container.decodeIfPresent(String.self, forKey: .releaseNotes) ?? "Bug fixes and performance improvements."

        if let dateStr = try container.decodeIfPresent(String.self, forKey: .publishedAt) {
            let iso = ISO8601DateFormatter()
            self.publishedAt = iso.date(from: dateStr)
        } else {
            self.publishedAt = nil
        }

        if let assets = try container.decodeIfPresent([Asset].self, forKey: .assets) {
            let matched = assets.first { $0.name.hasSuffix(".zip") || $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".app.zip") }
            if let targetAsset = matched ?? assets.first, let url = URL(string: targetAsset.browserDownloadURL) {
                self.downloadURL = url
            } else {
                self.downloadURL = nil
            }
        } else {
            self.downloadURL = nil
        }
    }

    public init(tagName: String, releaseNotes: String, downloadURL: URL?, publishedAt: Date? = nil) {
        self.tagName = tagName
        self.releaseNotes = releaseNotes
        self.downloadURL = downloadURL
        self.publishedAt = publishedAt
    }
}

public enum UpdateState: Sendable, Equatable {
    case idle
    case checking
    case updateAvailable(version: String, releaseNotes: String, downloadURL: URL?)
    case upToDate
    case downloading(progress: Double)
    case readyToInstall(fileURL: URL)
    case failed(message: String)
}

@Observable
public final class UpdateService: @unchecked Sendable {
    public static let shared = UpdateService()

    public var state: UpdateState = .idle
    public var autoCheckUpdates: Bool {
        get { UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoCheckUpdates") }
    }
    public var lastCheckDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastUpdateCheckDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastUpdateCheckDate") }
    }

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private let releaseAPIURL = URL(string: "https://api.github.com/repos/dakshraman/MacPurge/releases/latest")!

    private init() {}

    public func checkForUpdates(isUserInitiated: Bool = false) async {
        if !isUserInitiated && !autoCheckUpdates { return }

        state = .checking
        lastCheckDate = Date()

        do {
            var request = URLRequest(url: releaseAPIURL)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("MacPurge-Updater/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                if isUserInitiated {
                    state = .upToDate
                } else {
                    state = .idle
                }
                return
            }

            let release = try JSONDecoder().decode(AppReleaseInfo.self, from: data)
            let latestVersionClean = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

            if isVersionNewer(latest: latestVersionClean, current: currentVersion) {
                state = .updateAvailable(
                    version: latestVersionClean,
                    releaseNotes: release.releaseNotes,
                    downloadURL: release.downloadURL
                )
            } else {
                state = isUserInitiated ? .upToDate : .idle
            }
        } catch {
            if isUserInitiated {
                state = .failed(message: "Unable to reach update server. You are on version \(currentVersion).")
            } else {
                state = .idle
            }
        }
    }

    public func downloadAndInstallUpdate(from url: URL) async {
        state = .downloading(progress: 0.1)

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            state = .downloading(progress: 1.0)
            state = .readyToInstall(fileURL: tempURL)

            #if os(macOS)
            applyUpdate(from: tempURL)
            #endif
        } catch {
            state = .failed(message: "Download failed: \(error.localizedDescription)")
        }
    }

    #if os(macOS)
    private func applyUpdate(from downloadedArchive: URL) {
        let currentAppURL = Bundle.main.bundleURL

        // Create temporary extraction directory
        let fm = FileManager.default
        let tempExtractDir = fm.temporaryDirectory.appendingPathComponent("MacPurgeUpdate_\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)

            // Prepare helper updater script to replace running bundle and relaunch
            let scriptContent = """
            #!/bin/bash
            sleep 1
            ditto -x -k "\(downloadedArchive.path)" "\(tempExtractDir.path)"
            EXTRACTED_APP=$(find "\(tempExtractDir.path)" -name "*.app" -maxdepth 2 | head -n 1)
            if [ -n "$EXTRACTED_APP" ]; then
                rm -rf "\(currentAppURL.path)"
                cp -R "$EXTRACTED_APP" "\(currentAppURL.path)"
                open "\(currentAppURL.path)"
            fi
            rm -rf "\(tempExtractDir.path)"
            rm -f "\(downloadedArchive.path)"
            """

            let scriptURL = fm.temporaryDirectory.appendingPathComponent("update_script_\(UUID().uuidString).sh")
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            // Spawn detached bash process to replace binary after exit
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]
            try process.run()

            // Gracefully terminate current running app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        } catch {
            state = .failed(message: "Failed to apply update: \(error.localizedDescription)")
        }
    }
    #endif

    private func isVersionNewer(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        for (l, c) in zip(latestComponents, currentComponents) {
            if l > c { return true }
            if l < c { return false }
        }
        return latestComponents.count > currentComponents.count
    }
}
