import XCTest
@testable import peek

@MainActor
final class FileIndexTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-fileindex-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func write(_ rel: String) throws {
        let url = tmp.appendingPathComponent(rel)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "x".write(to: url, atomically: true, encoding: .utf8)
    }

    func testWalkFindsMarkdownByDefault() throws {
        try write("a.md")
        try write("b.markdown")
        try write("c.txt")
        let urls = FileIndex.walk(root: tmp, showAllFiles: false)
        let names = Set(urls.map(\.lastPathComponent))
        XCTAssertEqual(names, ["a.md", "b.markdown"])
    }

    func testWalkAllFilesIncludesNonMarkdown() throws {
        try write("a.md")
        try write("c.txt")
        let urls = FileIndex.walk(root: tmp, showAllFiles: true)
        let names = Set(urls.map(\.lastPathComponent))
        XCTAssertEqual(names, ["a.md", "c.txt"])
    }

    func testWalkRecursesIntoSubdirs() throws {
        try write("docs/intro.md")
        try write("docs/sub/deep.md")
        let urls = FileIndex.walk(root: tmp, showAllFiles: false)
        let names = Set(urls.map(\.lastPathComponent))
        XCTAssertEqual(names, ["intro.md", "deep.md"])
    }

    func testWalkSkipsIgnoredDirsInMdMode() throws {
        try write("docs/intro.md")
        try write("node_modules/lib/x.md")
        try write("__pycache__/inside.md")
        let urls = FileIndex.walk(root: tmp, showAllFiles: false)
        let names = Set(urls.map(\.lastPathComponent))
        XCTAssertEqual(names, ["intro.md"])
    }

    func testWalkIncludesIgnoredDirsWhenShowAll() throws {
        try write("docs/intro.md")
        try write("node_modules/lib/x.md")
        let urls = FileIndex.walk(root: tmp, showAllFiles: true)
        let names = urls.map(\.lastPathComponent)
        XCTAssertTrue(names.contains("x.md"))
    }

    func testBuildPublishesAsync() async throws {
        try write("a.md")
        try write("b.md")
        let index = FileIndex()
        index.build(root: tmp, showAllFiles: false)
        try await waitUntilTrue { index.files.count == 2 }
        XCTAssertFalse(index.isBuilding)
    }

    func testBuildSupersedesEarlierWalks() async throws {
        // Kick off two builds against different roots; the latest wins.
        let other = tmp.appendingPathComponent("other-root", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try write("a.md")
        try "x".write(to: other.appendingPathComponent("z.md"), atomically: true, encoding: .utf8)

        let index = FileIndex()
        index.build(root: tmp, showAllFiles: false)
        index.build(root: other, showAllFiles: false)
        try await waitUntilTrue { index.files.contains { $0.lastPathComponent == "z.md" } }
        // No leak from the first walk's a.md
        let names = Set(index.files.map(\.lastPathComponent))
        XCTAssertEqual(names, ["z.md"])
    }

    func testClearWipesFiles() async throws {
        try write("a.md")
        let index = FileIndex()
        index.build(root: tmp, showAllFiles: false)
        try await waitUntilTrue { !index.files.isEmpty }
        index.clear()
        XCTAssertEqual(index.files.count, 0)
    }

    private func waitUntilTrue(
        timeout: TimeInterval = 1.0,
        _ predicate: @MainActor () -> Bool
    ) async throws {
        let start = Date()
        while !predicate() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("predicate not met within \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
