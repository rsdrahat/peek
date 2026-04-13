import Foundation

/// Persistent MRU list of recently opened files and folders.
/// Backed by UserDefaults; entries are deduped by standardized path,
/// capped at `maxEntries`, and ordered most-recent-first.
@MainActor
final class RecentFilesStore: ObservableObject {
    static let shared = RecentFilesStore()

    static let maxEntries = 10
    static let defaultsKey = "peek.recents"

    @Published private(set) var recents: [URL] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.recents = Self.load(from: defaults)
    }

    func all() -> [URL] { recents }

    /// Returns recents that still exist on disk. Stale entries are pruned in place.
    func existing() -> [URL] {
        let fm = FileManager.default
        let alive = recents.filter { fm.fileExists(atPath: $0.path) }
        if alive.count != recents.count {
            recents = alive
            persist()
        }
        return alive
    }

    func add(_ url: URL) {
        let standardized = url.standardizedFileURL
        var next = recents.filter { $0.path != standardized.path }
        next.insert(standardized, at: 0)
        if next.count > Self.maxEntries {
            next = Array(next.prefix(Self.maxEntries))
        }
        recents = next
        persist()
    }

    func clear() {
        recents = []
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func persist() {
        let paths = recents.map(\.path)
        defaults.set(paths, forKey: Self.defaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> [URL] {
        let paths = (defaults.array(forKey: defaultsKey) as? [String]) ?? []
        return paths.map { URL(fileURLWithPath: $0) }
    }
}
