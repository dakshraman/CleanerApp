import Foundation
import Observation
import SwiftUI

enum AppPhase: Sendable, Equatable {
    case idle
    case scanning(currentCategory: String, progress: Double)
    case scanned
    case cleaning(category: String, progress: Double)
    case complete
}

enum SmartCareStage: String, CaseIterable, Sendable {
    case scanningCleanup = "Analyzing System Junk..."
    case scanningSecurity = "Checking Security & Malware..."
    case scanningSpeed = "Evaluating System Performance & Startup Items..."
    case scanningApps = "Inspecting App Leftovers..."
    case complete = "Scan Complete"
}

@Observable
final class CleanupViewModel {
    // Navigation
    var selectedTab: NavigationTab = .smartCare

    // Smart Care State
    var isSmartScanning: Bool = false
    var isSmartCleaning: Bool = false
    var smartScanProgress: Double = 0.0
    var smartCurrentStage: String = ""
    var smartScanCompleted: Bool = false
    var smartCleanCompleted: Bool = false

    // App Phases (Category Scanning & Cleaning)
    var phase: AppPhase = .idle
    var scanResults: [CleanupCategory: ScanResult] = [:]
    var cleanupResults: [CleanupResult] = []
    var selectedCategory: CleanupCategory?
    var showConfirmation = false
    var isCleaningSingleCategory = false
    var categoryToClean: CleanupCategory?
    var diskInfo = AppState()

    // Selection
    var selectedCategories: Set<CleanupCategory> = Set(CleanupCategory.allCases)
    var selectedItemIDs: [CleanupCategory: Set<UUID>] = [:]

    // Installed Applications & Uninstaller
    var installedApps: [InstalledAppInfo] = []
    var selectedAppIDs: Set<UUID> = []
    var isScanningApps: Bool = false

    // Optimization & Startup Items
    var startupItems: [StartupItem] = []
    var isScanningOptimization: Bool = false

    // Maintenance
    var systemMemory: SystemMemoryInfo = SystemMemoryInfo()
    var maintenanceTasks: [MaintenanceTaskItem] = [
        MaintenanceTaskItem(id: "free_ram", title: "Free Up RAM", description: "Reclaim inactive memory caches and flush allocated buffers to speed up system responsiveness.", icon: "memorychip.fill", category: "Memory"),
        MaintenanceTaskItem(id: "flush_dns", title: "Flush DNS Cache", description: "Reset local DNS resolver cache to fix website loading errors and network routing delays.", icon: "network", category: "Network"),
        MaintenanceTaskItem(id: "speed_up_mail", title: "Speed Up Apple Mail", description: "Reindex Mail SQLite database envelopes for instant search and faster inbox sync.", icon: "envelope.fill", category: "Applications"),
        MaintenanceTaskItem(id: "rebuild_spotlight", title: "Reindex Spotlight Search", description: "Request immediate background re-indexing of file search metadata.", icon: "sparkle.magnifyingglass", category: "System"),
        MaintenanceTaskItem(id: "periodic_scripts", title: "Run Maintenance Scripts", description: "Trigger system log rotation, temp socket cleanup, and crash diagnostic report sweeps.", icon: "terminal.fill", category: "System"),
        MaintenanceTaskItem(id: "flush_font_cache", title: "Rebuild Font Cache", description: "Remove corrupted font registry databases that can cause text rendering glitches.", icon: "textformat", category: "System")
    ]

    // Space Lens
    var spaceLensItems: [SpaceLensItem] = []
    var isScanningSpaceLens: Bool = false

    // Specific Module Scan Results
    var privacyScanResult: ScanResult?
    var trashScanResult: ScanResult?

    // Settings
    var useTrash: Bool = true
    var downloadAgeDaysThreshold: Int = 30
    var largeFileThresholdMB: Int = 100
    var includeXcodeArchives: Bool = false

    var isOperating: Bool = false
    private var activeTask: Task<Void, Never>?

    // Services
    private let uninstallerService = AppUninstallerService()
    private let optimizationService = OptimizationService()
    private let maintenanceService = MaintenanceService.shared
    private let privacyService = PrivacyService()
    private let trashService = TrashCleanerService()
    private let spaceLensService = SpaceLensService()

    // MARK: - Computed Properties

    var totalScannableSpace: Int64 {
        scanResults.values.reduce(0) { $0 + $1.totalSize }
    }

    var selectedScannableSpace: Int64 {
        var total: Int64 = 0
        for category in filteredCategories where selectedCategories.contains(category) {
            total += selectedSpace(for: category)
        }
        return total
    }

    var filteredCategories: [CleanupCategory] {
        #if os(macOS)
        CleanupCategory.allCases
        #else
        CleanupCategory.allCases.filter { $0.platforms.contains(.iOS) }
        #endif
    }

    var hasSelectedItems: Bool {
        selectedScannableSpace > 0
    }

    var totalFreedSpace: Int64 {
        cleanupResults.reduce(0) { $0 + $1.spaceFreed }
    }

    var totalErrors: Int {
        cleanupResults.reduce(0) { $0 + $1.errors.count }
    }

    // Smart Care Aggregates
    var smartCleanupSpace: Int64 {
        let junkCategories: [CleanupCategory] = [.systemCache, .tempFiles, .appLogs, .xcodeDerived, .downloads]
        return scanResults
            .filter { junkCategories.contains($0.key) }
            .values
            .reduce(0) { $0 + $1.totalSize }
    }

    var smartMalwareCount: Int {
        scanResults[.malware]?.items.count ?? 0
    }

    var smartLeftoversCount: Int {
        let remnantsCount = scanResults[.appRemnants]?.items.count ?? 0
        let brokenStartupCount = startupItems.filter { $0.isBroken }.count
        return remnantsCount + brokenStartupCount
    }

    var brokenStartupItemsCount: Int {
        startupItems.filter { $0.isBroken }.count
    }

    // MARK: - Disk & Memory

    func refreshDiskInfo() {
        diskInfo = AppState(
            totalDiskSpace: FileManager.totalDiskSpace,
            usedDiskSpace: FileManager.usedDiskSpace,
            freeDiskSpace: FileManager.freeDiskSpace
        )
    }

    func refreshMemoryInfo() {
        systemMemory = maintenanceService.getMemoryInfo()
    }

    // MARK: - Smart Care Full Scan & Clean

    func runSmartScan() async {
        guard !isOperating else { return }
        isOperating = true
        isSmartScanning = true
        smartScanCompleted = false
        smartCleanCompleted = false
        smartScanProgress = 0.0
        defer {
            isOperating = false
            isSmartScanning = false
        }

        // Stage 1: System Junk
        smartCurrentStage = "Scanning Caches & System Junk..."
        smartScanProgress = 0.15
        let cacheRes = await CacheCleanerService().scan()
        let tempRes = await TempFilesCleanerService().scan()
        let logRes = await LogCleanerService().scan()
        scanResults[.systemCache] = cacheRes
        scanResults[.tempFiles] = tempRes
        scanResults[.appLogs] = logRes
        selectedItemIDs[.systemCache] = Set(cacheRes.items.map { $0.id })
        selectedItemIDs[.tempFiles] = Set(tempRes.items.map { $0.id })
        selectedItemIDs[.appLogs] = Set(logRes.items.map { $0.id })
        await Task.yield()

        // Stage 2: Security & Malware
        smartCurrentStage = "Checking Malware Signatures & Launch Agents..."
        smartScanProgress = 0.45
        let malwareRes = await MalwareScanService().scan()
        scanResults[.malware] = malwareRes
        selectedItemIDs[.malware] = Set(malwareRes.items.map { $0.id })
        await Task.yield()

        // Stage 3: Performance, Memory & Startup items
        smartCurrentStage = "Inspecting Memory & Background Startup Daemons..."
        smartScanProgress = 0.70
        refreshMemoryInfo()
        startupItems = await optimizationService.scanStartupItems()
        let xcodeRes = await XcodeCleanerService(includeArchives: includeXcodeArchives).scan()
        scanResults[.xcodeDerived] = xcodeRes
        selectedItemIDs[.xcodeDerived] = Set(xcodeRes.items.map { $0.id })
        await Task.yield()

        // Stage 4: App Remnants & Leftovers
        smartCurrentStage = "Detecting Leftover App Data & Broken Login Items..."
        smartScanProgress = 0.90
        let remnantsRes = await AppRemnantsService().scan()
        scanResults[.appRemnants] = remnantsRes
        selectedItemIDs[.appRemnants] = Set(remnantsRes.items.map { $0.id })

        smartScanProgress = 1.0
        smartScanCompleted = true
        refreshDiskInfo()
    }

    func runSmartClean() async {
        guard !isOperating else { return }
        isOperating = true
        isSmartCleaning = true
        defer {
            isOperating = false
            isSmartCleaning = false
        }

        // Clean selected junk categories
        let targets: [CleanupCategory] = [.systemCache, .tempFiles, .appLogs, .xcodeDerived, .malware, .appRemnants]
        cleanupResults = []

        for category in targets {
            if scanResults[category] != nil {
                let res = await executeClean(category)
                cleanupResults.append(res)
                removeCleanedItems(for: category)
            }
        }

        // Remove broken startup items from uninstalled apps
        await removeAllBrokenStartupItems()

        // Run Free RAM as part of smart clean
        _ = await maintenanceService.runTask(id: "free_ram")
        refreshMemoryInfo()
        refreshDiskInfo()
        smartCleanCompleted = true
    }

    // MARK: - Optimization & Startup Items

    func scanOptimizationItems() async {
        isScanningOptimization = true
        defer { isScanningOptimization = false }
        startupItems = await optimizationService.scanStartupItems()
    }

    func removeStartupItem(_ item: StartupItem) async {
        let res = optimizationService.removeStartupItem(item)
        if res.success {
            startupItems.removeAll { $0.id == item.id }
        }
    }

    func removeAllBrokenStartupItems() async {
        let broken = startupItems.filter { $0.isBroken }
        for item in broken {
            let res = optimizationService.removeStartupItem(item)
            if res.success {
                startupItems.removeAll { $0.id == item.id }
            }
        }
    }

    // MARK: - App Uninstaller

    func scanInstalledApps() async {
        isScanningApps = true
        defer { isScanningApps = false }
        installedApps = await uninstallerService.scanInstalledApps()
    }

    func toggleAppSelection(_ app: InstalledAppInfo) {
        if selectedAppIDs.contains(app.id) {
            selectedAppIDs.remove(app.id)
        } else {
            selectedAppIDs.insert(app.id)
        }
    }

    func uninstallSelectedApps() async {
        let toUninstall = installedApps.filter { selectedAppIDs.contains($0.id) }
        guard !toUninstall.isEmpty else { return }

        for app in toUninstall {
            let res = uninstallerService.uninstall(app: app, useTrash: useTrash)
            if res.success {
                installedApps.removeAll { $0.id == app.id }
                selectedAppIDs.remove(app.id)
            }
        }
        refreshDiskInfo()
    }

    func uninstallSingleApp(_ app: InstalledAppInfo) async {
        let res = uninstallerService.uninstall(app: app, useTrash: useTrash)
        if res.success {
            installedApps.removeAll { $0.id == app.id }
            selectedAppIDs.remove(app.id)
        }
        refreshDiskInfo()
    }

    // MARK: - Maintenance Tasks

    func runMaintenanceTask(id: String) async {
        guard let index = maintenanceTasks.firstIndex(where: { $0.id == id }) else { return }
        maintenanceTasks[index].isRunning = true
        let result = await maintenanceService.runTask(id: id)
        maintenanceTasks[index].isRunning = false
        maintenanceTasks[index].isCompleted = result.success
        maintenanceTasks[index].statusMessage = result.message
        refreshMemoryInfo()
        refreshDiskInfo()
    }

    func runAllMaintenanceTasks() async {
        for task in maintenanceTasks {
            await runMaintenanceTask(id: task.id)
        }
    }

    // MARK: - Space Lens

    func scanSpaceLens() async {
        isScanningSpaceLens = true
        defer { isScanningSpaceLens = false }
        spaceLensItems = await spaceLensService.scanSpaceLens()
    }

    // MARK: - Privacy & Trash

    func scanPrivacy() async {
        let res = await privacyService.scan()
        privacyScanResult = res
        scanResults[.appLogs] = res
    }

    func scanTrash() async {
        let res = await trashService.scan()
        trashScanResult = res
        scanResults[.tempFiles] = res
    }

    // MARK: - Category & Granular Selection

    func isItemSelected(_ item: ScannedItem, in category: CleanupCategory) -> Bool {
        selectedItemIDs[category]?.contains(item.id) ?? false
    }

    func toggleItemSelection(_ item: ScannedItem, in category: CleanupCategory) {
        var set = selectedItemIDs[category] ?? []
        if set.contains(item.id) {
            set.remove(item.id)
        } else {
            set.insert(item.id)
        }
        selectedItemIDs[category] = set
    }

    func selectAllItems(in category: CleanupCategory) {
        guard let items = scanResults[category]?.items else { return }
        selectedItemIDs[category] = Set(items.map { $0.id })
    }

    func deselectAllItems(in category: CleanupCategory) {
        selectedItemIDs[category] = []
    }

    func selectedSpace(for category: CleanupCategory) -> Int64 {
        guard let result = scanResults[category] else { return 0 }
        let selectedIDs = selectedItemIDs[category] ?? []
        return result.items
            .filter { selectedIDs.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    func selectedItemCount(for category: CleanupCategory) -> Int {
        guard let result = scanResults[category] else { return 0 }
        let selectedIDs = selectedItemIDs[category] ?? []
        return result.items.filter { selectedIDs.contains($0.id) }.count
    }

    // MARK: - Scan Operations

    func scanAll() async {
        guard !isOperating else { return }
        isOperating = true
        defer { isOperating = false }

        phase = .scanning(currentCategory: "", progress: 0)
        scanResults = [:]
        selectedItemIDs = [:]
        cleanupResults = []

        let cats = filteredCategories
        for (index, category) in cats.enumerated() {
            if Task.isCancelled { break }
            phase = .scanning(
                currentCategory: category.rawValue,
                progress: Double(index) / Double(cats.count)
            )
            await Task.yield()

            let result = await scanCategory(category)
            scanResults[category] = result

            if category.defaultSelectItemsOnScan {
                selectedItemIDs[category] = Set(result.items.map { $0.id })
            } else {
                selectedItemIDs[category] = []
            }
        }

        phase = .scanned
        refreshDiskInfo()
    }

    func scanSingleCategory(_ category: CleanupCategory) async {
        guard !isOperating else { return }
        isOperating = true
        defer { isOperating = false }

        phase = .scanning(currentCategory: category.rawValue, progress: 0.5)
        let result = await scanCategory(category)
        scanResults[category] = result

        if category.defaultSelectItemsOnScan {
            selectedItemIDs[category] = Set(result.items.map { $0.id })
        } else {
            selectedItemIDs[category] = []
        }

        phase = .scanned
        refreshDiskInfo()
    }

    private func scanCategory(_ category: CleanupCategory) async -> ScanResult {
        let service = makeService(for: category)
        return await Task.detached(priority: .userInitiated) {
            await service.scan()
        }.value
    }

    private func makeService(for category: CleanupCategory) -> any CleanupService {
        switch category {
        case .systemCache:
            return CacheCleanerService()
        case .tempFiles:
            return TempFilesCleanerService()
        case .duplicateFiles:
            return DuplicateFileService()
        case .largeFiles:
            return LargeFileService(minimumSizeMB: largeFileThresholdMB)
        case .appLogs:
            return LogCleanerService()
        case .iosSimulator:
            return SimulatorCleanerService()
        case .downloads:
            return DownloadCleanerService(minAgeDays: downloadAgeDaysThreshold)
        case .xcodeDerived:
            return XcodeCleanerService(includeArchives: includeXcodeArchives)
        case .malware:
            return MalwareScanService()
        case .appRemnants:
            return AppRemnantsService()
        }
    }

    func cancelOperation() {
        activeTask?.cancel()
        activeTask = nil
        isOperating = false
        isSmartScanning = false
        isSmartCleaning = false
        if case .scanning = phase {
            phase = scanResults.isEmpty ? .idle : .scanned
        } else if case .cleaning = phase {
            phase = .scanned
        }
    }

    // MARK: - Clean Operations

    func requestCleanSelected() {
        guard hasSelectedItems, !isOperating else { return }
        isCleaningSingleCategory = false
        categoryToClean = nil
        showConfirmation = true
    }

    func requestCleanCategory(_ category: CleanupCategory) {
        guard !isOperating else { return }
        guard selectedSpace(for: category) > 0 else { return }
        isCleaningSingleCategory = true
        categoryToClean = category
        showConfirmation = true
    }

    func confirmClean() async {
        showConfirmation = false
        if isCleaningSingleCategory, let cat = categoryToClean {
            await cleanSingleCategory(cat)
        } else {
            await cleanSelected()
        }
    }

    private func cleanSingleCategory(_ category: CleanupCategory) async {
        guard !isOperating else { return }
        isOperating = true
        defer { isOperating = false }

        phase = .cleaning(category: category.rawValue, progress: 0.5)
        cleanupResults = []

        let result = await executeClean(category)
        cleanupResults.append(result)
        removeCleanedItems(for: category)

        phase = .complete
        refreshDiskInfo()
    }

    func cleanSelected() async {
        guard !isOperating else { return }
        isOperating = true
        defer { isOperating = false }

        let toClean = filteredCategories.filter {
            selectedCategories.contains($0) && selectedSpace(for: $0) > 0
        }
        guard !toClean.isEmpty else { return }

        phase = .cleaning(category: "", progress: 0)
        cleanupResults = []

        for (index, category) in toClean.enumerated() {
            if Task.isCancelled { break }
            phase = .cleaning(
                category: category.rawValue,
                progress: Double(index) / Double(toClean.count)
            )
            await Task.yield()

            let result = await executeClean(category)
            cleanupResults.append(result)
            removeCleanedItems(for: category)
        }

        phase = .complete
        refreshDiskInfo()
    }

    private func executeClean(_ category: CleanupCategory) async -> CleanupResult {
        guard let scanResult = scanResults[category] else {
            return CleanupResult(category: category, filesRemoved: 0, spaceFreed: 0, errors: [], duration: 0)
        }

        let selectedIDs = selectedItemIDs[category] ?? []
        let itemsToClean = scanResult.items.filter { selectedIDs.contains($0.id) }

        guard !itemsToClean.isEmpty else {
            return CleanupResult(category: category, filesRemoved: 0, spaceFreed: 0, errors: [], duration: 0)
        }

        #if os(macOS)
        let shouldTrash = useTrash
        let method: RemovalMethod = shouldTrash ? .trash : .delete
        #else
        let shouldTrash = false
        let method: RemovalMethod = .delete
        #endif

        return await Task.detached(priority: .userInitiated) { () -> CleanupResult in
            let start = Date()
            #if os(macOS)
            let result = shouldTrash ? FileTrashService.trash(items: itemsToClean) : FileTrashService.delete(items: itemsToClean)
            #else
            let result = FileTrashService.delete(items: itemsToClean)
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

    private func removeCleanedItems(for category: CleanupCategory) {
        guard let scanResult = scanResults[category] else { return }
        let selectedIDs = selectedItemIDs[category] ?? []
        let remainingItems = scanResult.items.filter { !selectedIDs.contains($0.id) }
        let remainingTotalSize = remainingItems.reduce(0) { $0 + $1.size }

        scanResults[category] = ScanResult(
            id: scanResult.id,
            category: category,
            items: remainingItems,
            totalSize: remainingTotalSize,
            duration: scanResult.duration
        )
        selectedItemIDs[category] = []
    }

    func selectCategory(_ category: CleanupCategory, selected: Bool) {
        if selected {
            selectedCategories.insert(category)
        } else {
            selectedCategories.remove(category)
        }
    }

    func selectAll() {
        selectedCategories = Set(filteredCategories)
    }

    func deselectAll() {
        selectedCategories = []
    }

    func dismissComplete() {
        phase = .scanned
        cleanupResults = []
    }

    // MARK: - Formatting

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var confirmationMessage: String {
        #if os(macOS)
        let methodText = useTrash ? "moved to Trash" : "permanently deleted"
        #else
        let methodText = "permanently deleted"
        #endif

        if isCleaningSingleCategory, let cat = categoryToClean {
            let count = selectedItemCount(for: cat)
            let space = formatBytes(selectedSpace(for: cat))
            return "Clean \(count) item\(count == 1 ? "" : "s") in \(cat.rawValue)? This will free up \(space). Files will be \(methodText)."
        } else {
            let totalSpace = formatBytes(selectedScannableSpace)
            var count = 0
            for cat in filteredCategories where selectedCategories.contains(cat) {
                count += selectedItemCount(for: cat)
            }
            return "Clean \(count) selected item\(count == 1 ? "" : "s")? This will free up \(totalSpace). Files will be \(methodText)."
        }
    }
}
