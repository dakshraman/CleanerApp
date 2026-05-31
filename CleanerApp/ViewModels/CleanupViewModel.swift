import Foundation
import Observation

enum AppPhase: Sendable, Equatable {
    case idle
    case scanning(currentCategory: String, progress: Double)
    case scanned
    case cleaning(progress: Double)
    case complete
}

@Observable
final class CleanupViewModel {
    var phase: AppPhase = .idle
    var scanResults: [CleanupCategory: ScanResult] = [:]
    var cleanupResults: [CleanupResult] = []
    var selectedCategory: CleanupCategory?
    var showConfirmation = false
    var cleaningAll = false
    var diskInfo = AppState()
    var selectedCategories: Set<CleanupCategory> = Set(CleanupCategory.allCases)
    var useTrash = true
    var isOperating = false

    var totalScannableSpace: Int64 {
        scanResults.values.reduce(0) { $0 + $1.totalSize }
    }

    var selectedScannableSpace: Int64 {
        scanResults.filter { selectedCategories.contains($0.key) }.values.reduce(0) { $0 + $1.totalSize }
    }

    var filteredCategories: [CleanupCategory] {
        #if os(macOS)
        CleanupCategory.allCases
        #else
        CleanupCategory.allCases.filter { $0.platforms.contains(.iOS) }
        #endif
    }

    var hasSelectedItems: Bool {
        !selectedCategories.isEmpty && scanResults.contains(where: { selectedCategories.contains($0.key) && $0.value.totalSize > 0 })
    }

    var totalFreedSpace: Int64 {
        cleanupResults.reduce(0) { $0 + $1.spaceFreed }
    }

    var totalErrors: Int {
        cleanupResults.reduce(0) { $0 + $1.errors.count }
    }

    var selectedCategoryScanResult: ScanResult? {
        guard let cat = selectedCategory else { return nil }
        return scanResults[cat]
    }

    // MARK: - Disk Info

    func refreshDiskInfo() {
        diskInfo = AppState(
            totalDiskSpace: FileManager.totalDiskSpace,
            usedDiskSpace: FileManager.usedDiskSpace,
            freeDiskSpace: FileManager.freeDiskSpace
        )
    }

    private let services: [CleanupCategory: any CleanupService] = [
        .systemCache: CacheCleanerService(),
        .tempFiles: TempFilesCleanerService(),
        .duplicateFiles: DuplicateFileService(),
        .largeFiles: LargeFileService(),
        .appLogs: LogCleanerService(),
        .iosSimulator: SimulatorCleanerService(),
        .downloads: DownloadCleanerService(),
        .xcodeDerived: XcodeCleanerService(),
        .malware: MalwareScanService(),
        .appRemnants: AppRemnantsService(),
    ]

    // MARK: - Scan

    func scanAll() async {
        guard !isOperating else { return }
        isOperating = true
        defer { isOperating = false }

        phase = .scanning(currentCategory: "", progress: 0)
        scanResults = [:]
        selectedCategory = nil

        let cats = filteredCategories
        for (index, category) in cats.enumerated() {
            phase = .scanning(currentCategory: category.rawValue, progress: Double(index) / Double(cats.count))
            await Task.yield()
            let result = await scanCategory(category)
            scanResults[category] = result
        }

        phase = .scanned
        refreshDiskInfo()
    }

    private func scanCategory(_ category: CleanupCategory) async -> ScanResult {
        guard let service = services[category] else {
            return ScanResult(category: category, items: [], totalSize: 0, duration: 0)
        }
        return await Task.detached(priority: .userInitiated) {
            await service.scan()
        }.value
    }

    // MARK: - Selection

    func selectCategory(_ category: CleanupCategory, selected: Bool) {
        if selected { selectedCategories.insert(category) }
        else { selectedCategories.remove(category) }
    }

    func selectAll() { selectedCategories = Set(filteredCategories) }
    func deselectAll() { selectedCategories = [] }

    // MARK: - Clean

    func requestCleanSelected() {
        guard hasSelectedItems, !isOperating else { return }
        showConfirmation = true
        cleaningAll = true
    }

    func requestCleanCategory(_ category: CleanupCategory) {
        guard !isOperating else { return }
        selectedCategory = category
        showConfirmation = true
        cleaningAll = false
    }

    func confirmClean() async {
        showConfirmation = false
        await cleanSelected()
    }

    func cleanSelected() async {
        guard !isOperating else { return }
        isOperating = true
        defer { isOperating = false }

        let toClean = filteredCategories.filter { selectedCategories.contains($0) }
        guard !toClean.isEmpty else { return }

        phase = .cleaning(progress: 0)
        cleanupResults = []

        for (index, category) in toClean.enumerated() {
            phase = .cleaning(progress: Double(index) / Double(toClean.count))
            await Task.yield()
            let result = await executeClean(category)
            cleanupResults.append(result)
            scanResults[category] = nil
        }

        if let sel = selectedCategory, toClean.contains(sel) {
            selectedCategory = nil
        }

        phase = .complete
        refreshDiskInfo()
    }

    private func executeClean(_ category: CleanupCategory) async -> CleanupResult {
        let items = scanResults[category]?.items ?? []
        guard !items.isEmpty else {
            return CleanupResult(category: category, filesRemoved: 0, spaceFreed: 0, errors: [], duration: 0)
        }

        #if os(macOS)
        let shouldTrash = useTrash
        #else
        let shouldTrash = false
        #endif

        return await Task.detached(priority: .userInitiated) { () -> CleanupResult in
            let start = Date()
            #if os(macOS)
            let method: RemovalMethod = shouldTrash ? .trash : .delete
            let result = shouldTrash ? FileTrashService.trash(items: items) : FileTrashService.delete(items: items)
            #else
            let method: RemovalMethod = .delete
            let result = FileTrashService.delete(items: items)
            #endif
            return CleanupResult(
                category: category,
                filesRemoved: result.removed,
                spaceFreed: result.freed,
                errors: result.errors,
                duration: Date().timeIntervalSince(start),
                method: method
            )
        }.value
    }

    // MARK: - Phase Transitions

    func dismissComplete() {
        phase = .idle
        cleanupResults = []
        selectedCategories = Set(filteredCategories)
    }

    // MARK: - Formatting

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var confirmationMessage: String {
        if cleaningAll {
            let count = selectedCategories.count
            let size = formatBytes(selectedScannableSpace)
            #if os(macOS)
            let method = useTrash ? "moved to Trash" : "permanently deleted"
            #else
            let method = "deleted"
            #endif
            return "Clean \(count) categor\(count == 1 ? "y" : "ies")? This will free up \(size). Files will be \(method)."
        } else if let cat = selectedCategory, let result = scanResults[cat] {
            return "Clean \(cat.rawValue)? \(result.itemCount) items (\(result.formattedTotalSize)) will be removed."
        }
        return ""
    }
}
