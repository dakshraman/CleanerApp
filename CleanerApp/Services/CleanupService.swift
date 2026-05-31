import Foundation

protocol CleanupService {
    func scan() async -> ScanResult
}
