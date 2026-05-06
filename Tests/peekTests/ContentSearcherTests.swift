import XCTest
@testable import peek

@MainActor
final class ContentSearcherTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-content-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func write(_ rel: String, _ body: String) throws -> URL {
        let url = tmp.appendingPathComponent(rel)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Pure scan (synchronous)

    func testScanFindsLineMatch() throws {
        let url = try write("notes.md", "alpha\nbeta\ngamma\n")
        let matches = ContentSearcher.scan(query: "beta", files: [url])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.lineNumber, 2)
        XCTAssertEqual(matches.first?.line, "beta")
    }

    func testScanIsCaseInsensitive() throws {
        let url = try write("notes.md", "Hello world")
        let matches = ContentSearcher.scan(query: "HELLO", files: [url])
        XCTAssertEqual(matches.count, 1)
    }

    func testScanReturnsMultipleHitsAcrossLines() throws {
        let url = try write("notes.md", "todo: fix\ndone\ntodo: revisit\n")
        let matches = ContentSearcher.scan(query: "todo", files: [url])
        XCTAssertEqual(matches.map(\.lineNumber), [1, 3])
    }

    func testScanSkipsLargeFiles() throws {
        // Build a file just over the size cap.
        let bigBody = String(repeating: "x", count: Int(ContentSearcher.maxFileSizeBytes) + 100)
        let url = try write("big.md", bigBody + "\nmagic-token\n")
        let matches = ContentSearcher.scan(query: "magic-token", files: [url])
        XCTAssertEqual(matches.count, 0, "files larger than maxFileSizeBytes must be skipped")
    }

    func testScanCapsResultsAtMaxResults() throws {
        // Many matches in one file.
        let lines = (0..<(ContentSearcher.maxResults + 50)).map { _ in "needle" }.joined(separator: "\n")
        let url = try write("haystack.md", lines)
        let matches = ContentSearcher.scan(query: "needle", files: [url])
        XCTAssertEqual(matches.count, ContentSearcher.maxResults)
    }

    func testScanReadsMultipleFiles() throws {
        let a = try write("a.md", "alpha\n")
        let b = try write("b.md", "alpha\nbeta\n")
        let matches = ContentSearcher.scan(query: "alpha", files: [a, b])
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(Set(matches.map(\.url.lastPathComponent)), ["a.md", "b.md"])
    }

    // MARK: - Async search

    func testSearchPublishesMatches() async throws {
        let a = try write("a.md", "find me\n")
        let b = try write("b.md", "no\n")
        let searcher = ContentSearcher()
        searcher.search(query: "find", in: [a, b])
        try await waitUntilTrue { !searcher.matches.isEmpty }
        XCTAssertEqual(searcher.matches.count, 1)
        XCTAssertFalse(searcher.isSearching)
    }

    func testEmptyQueryClearsMatches() async throws {
        let a = try write("a.md", "stuff\n")
        let searcher = ContentSearcher()
        searcher.search(query: "stuff", in: [a])
        try await waitUntilTrue { !searcher.matches.isEmpty }

        searcher.search(query: "", in: [a])
        XCTAssertTrue(searcher.matches.isEmpty)
        XCTAssertFalse(searcher.isSearching)
    }

    func testRapidQueriesCancelEarlierResults() async throws {
        let a = try write("a.md", "alpha\n")
        let b = try write("b.md", "beta\n")
        let searcher = ContentSearcher()
        searcher.search(query: "alpha", in: [a, b])
        searcher.search(query: "beta", in: [a, b])
        try await waitUntilTrue { searcher.matches.first?.line == "beta" }
        XCTAssertEqual(searcher.matches.count, 1)
        XCTAssertEqual(searcher.matches.first?.line, "beta")
    }

    func testClearCancelsInFlight() async throws {
        let a = try write("a.md", "stuff\n")
        let searcher = ContentSearcher()
        searcher.search(query: "stuff", in: [a])
        searcher.clear()
        // After clear, even after the debounce window passes, matches stays empty.
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertTrue(searcher.matches.isEmpty)
        XCTAssertFalse(searcher.isSearching)
    }

    private func waitUntilTrue(
        timeout: TimeInterval = 2.0,
        _ predicate: @MainActor () -> Bool
    ) async throws {
        let start = Date()
        while !predicate() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("predicate not met within \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
