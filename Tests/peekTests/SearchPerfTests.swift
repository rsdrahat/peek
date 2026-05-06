import XCTest
@testable import peek

/// Performance gates for v0.4 search. The CLAUDE.md target is "results
/// visible within a frame of typing on a 10k-file folder." A frame at
/// 60fps is 16.67ms — that's the per-keystroke fuzzy scoring budget.
/// Folder open (walk) and content scan have looser, but still strict,
/// budgets.
///
/// Sizes are kept at 5000 files so CI fixture creation is bounded; bounds
/// are scaled accordingly. Adjust if these get flaky on slow CI runners,
/// but don't relax silently — discuss the cause first.
@MainActor
final class SearchPerfTests: XCTestCase {
    private static let fileCount = 5_000
    private var tmp: URL!
    private var files: [URL] = []

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-search-perf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        // Build a synthetic folder. Spread across 50 subdirectories so the
        // walk exercises directory recursion, not just one big flat dir.
        files.reserveCapacity(Self.fileCount)
        for i in 0..<Self.fileCount {
            let bucket = "dir\(i % 50)"
            let dir = tmp.appendingPathComponent(bucket, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("file-\(i).md")
            try "# File \(i)\nsome body line\nanother line\n".write(to: url, atomically: true, encoding: .utf8)
            files.append(url)
        }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmp)
        files = []
    }

    /// Folder open: FileIndex.walk on 5k files should land well under 250ms.
    /// On a 10k-file folder we'd expect proportionally ~500ms which is the
    /// upper bound of "feels instant" for a one-time folder-open cost.
    func testFileIndexWalkPerformance() throws {
        let start = Date()
        let urls = FileIndex.walk(root: tmp, showAllFiles: false)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(urls.count, Self.fileCount)
        XCTAssertLessThan(elapsed, 0.25, "FileIndex.walk on \(Self.fileCount) files took \(elapsed)s; budget 0.25s")
    }

    /// Per-keystroke fuzzy scoring across 5k candidates. 16ms = one frame.
    /// We give it a 30ms ceiling: 2x headroom + room for sort.
    func testFuzzyScoringPerformance() throws {
        let names = files.map { $0.lastPathComponent }
        let query = "file"  // matches every candidate; worst case for ranking

        let start = Date()
        var scored: [(Double, String)] = []
        scored.reserveCapacity(names.count)
        for n in names {
            if let s = FuzzyMatch.score(query: query, in: n) {
                scored.append((s, n))
            }
        }
        scored.sort { $0.0 > $1.0 }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(scored.count, 0)
        XCTAssertLessThan(elapsed, 0.030, "fuzzy scoring on \(names.count) candidates took \(elapsed)s; budget 0.030s")
    }

    /// Content scan budget: per-query, after the 150ms debounce. The hard
    /// caps (10k files, 500KB per file, 200 results) keep this bounded; we
    /// just sanity-check the actual time on 5k small markdown files.
    func testContentScanPerformance() throws {
        let start = Date()
        let matches = ContentSearcher.scan(query: "body", files: files)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(matches.count, 0)
        XCTAssertLessThan(elapsed, 1.0, "content scan on \(files.count) files took \(elapsed)s; budget 1.0s")
    }
}
