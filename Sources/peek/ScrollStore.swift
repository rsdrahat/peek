import Foundation
import CryptoKit

/// Persists per-file scroll positions to disk. Keyed by a hash of the file's
/// canonical path so renames don't accidentally leak state across files.
actor ScrollStore {
    static let shared = ScrollStore()

    private var cache: [String: Double] = [:]
    private var loaded = false
    private var saveTask: Task<Void, Never>?

    private static var storeURL: URL? {
        let fm = FileManager.default
        guard let dir = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("peek", isDirectory: true) else { return nil }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("scroll.json")
    }

    func scrollY(for fileURL: URL) async -> Double {
        await loadIfNeeded()
        return cache[Self.key(fileURL)] ?? 0
    }

    func setScrollY(_ value: Double, for fileURL: URL) async {
        await loadIfNeeded()
        cache[Self.key(fileURL)] = value
        scheduleSave()
    }

    private func loadIfNeeded() async {
        guard !loaded else { return }
        loaded = true
        guard let url = Self.storeURL,
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return
        }
        cache = dict
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [cache] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            if let url = Self.storeURL,
               let data = try? JSONEncoder().encode(cache) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    static func key(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
