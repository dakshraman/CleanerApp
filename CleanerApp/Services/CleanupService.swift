import Foundation

protocol CleanupService: Sendable {
    func scan() async -> ScanResult
}
