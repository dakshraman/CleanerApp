import Foundation

enum FileTrashService {
    nonisolated static func trash(items: [ScannedItem]) -> (removed: Int, freed: Int64, errors: [String]) {
        var removed = 0
        var freed: Int64 = 0
        var errors: [String] = []
        let fm = FileManager.default

        for item in items {
            do {
                var resultingURL: NSURL?
                try fm.trashItem(at: item.url, resultingItemURL: &resultingURL)
                removed += 1
                freed += item.size
            } catch {
                errors.append("\(item.fileName): \(error.localizedDescription)")
            }
        }

        return (removed, freed, errors)
    }

    nonisolated static func delete(items: [ScannedItem]) -> (removed: Int, freed: Int64, errors: [String]) {
        var removed = 0
        var freed: Int64 = 0
        var errors: [String] = []
        let fm = FileManager.default

        for item in items {
            do {
                try fm.removeItem(at: item.url)
                removed += 1
                freed += item.size
            } catch {
                errors.append("\(item.fileName): \(error.localizedDescription)")
            }
        }

        return (removed, freed, errors)
    }
}
