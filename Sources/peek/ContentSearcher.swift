import Foundation

/// One line in one file that contains the current query.
struct ContentMatch: Identifiable, Hashable {
    let url: URL
    let lineNumber: Int   // 1-based
    let line: String

    var id: String { "\(url.path):\(lineNumber)" }
}

/// Scans file contents for a substring query. Synchronous read on a
/// detached Task with a 150ms keystroke debounce; result delivered on
/// MainActor. Subsequent searches cancel earlier in-flight ones via
/// Task.cancel + isCancelled checks.
///
/// v1 caps (per CLAUDE.md "no background indexer, results within a frame"):
/// - `maxFiles`: 10k files scanned per query
/// - `maxFileSizeBytes`: 500KB per file (skip larger)
/// - `maxResults`: 200 matches returned (hard cap so common queries like
///   "the" don't pin the UI under millions of rows)
@MainActor
final class ContentSearcher: ObservableObject {
    @Published private(set) var matches: [ContentMatch] = []
    @Published private(set) var isSearching: Bool = false

    private var task: Task<Void, Never>?

    nonisolated static let maxFiles = 10_000
    nonisolated static let maxFileSizeBytes: UInt64 = 500_000
    nonisolated static let maxResults = 200
    nonisolated static let debounceNanoseconds: UInt64 = 150_000_000

    func search(query: String, in files: [URL]) {
        task?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            matches = []
            isSearching = false
            return
        }

        let toScan = Array(files.prefix(Self.maxFiles))
        isSearching = true

        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            if Task.isCancelled { return }

            let result = await Task.detached(priority: .userInitiated) {
                ContentSearcher.scan(query: q, files: toScan)
            }.value

            if Task.isCancelled { return }
            self.matches = result
            self.isSearching = false
        }
    }

    func clear() {
        task?.cancel()
        matches = []
        isSearching = false
    }

    nonisolated static func scan(query: String, files: [URL]) -> [ContentMatch] {
        let fm = FileManager.default
        var out: [ContentMatch] = []
        out.reserveCapacity(64)

        for url in files {
            if out.count >= maxResults { break }

            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
            if size > maxFileSizeBytes { continue }

            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }

            var lineNum = 0
            text.enumerateLines { line, stop in
                lineNum += 1
                if line.range(of: query, options: .caseInsensitive) != nil {
                    out.append(ContentMatch(url: url, lineNumber: lineNum, line: line))
                    if out.count >= maxResults { stop = true }
                }
            }
        }
        return out
    }
}
