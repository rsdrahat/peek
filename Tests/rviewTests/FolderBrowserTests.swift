import XCTest
@testable import rview

@MainActor
final class FolderBrowserTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rview-folder-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func write(_ rel: String, _ body: String = "x") throws -> URL {
        let url = tmp.appendingPathComponent(rel)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testMarkdownOnlyByDefault() throws {
        _ = try write("a.md")
        _ = try write("b.markdown")
        _ = try write("c.txt")
        _ = try write("image.png")

        let b = FolderBrowser()
        b.open(rootURL: tmp)
        let names = (b.root?.children ?? []).map(\.name).sorted()
        XCTAssertEqual(names, ["a.md", "b.markdown"])
    }

    func testShowAllFilesIncludesEverything() throws {
        _ = try write("a.md")
        _ = try write("c.txt")

        let b = FolderBrowser()
        b.open(rootURL: tmp)
        b.showAllFiles = true
        let names = (b.root?.children ?? []).map(\.name).sorted()
        XCTAssertEqual(names, ["a.md", "c.txt"])
    }

    func testHidesDotfiles() throws {
        _ = try write("a.md")
        _ = try write(".hidden.md")
        _ = try write(".git/config")

        let b = FolderBrowser()
        b.open(rootURL: tmp)
        b.showAllFiles = true
        let names = Set((b.root?.children ?? []).map(\.name))
        XCTAssertEqual(names, ["a.md"])
    }

    func testFoldersFirstThenAlphabetical() throws {
        _ = try write("z-dir/inside.md")
        _ = try write("a.md")
        _ = try write("m.md")
        _ = try write("a-dir/inside.md")

        let b = FolderBrowser()
        b.open(rootURL: tmp)
        let names = (b.root?.children ?? []).map(\.name)
        XCTAssertEqual(names, ["a-dir", "z-dir", "a.md", "m.md"])
    }

    func testSkipsEmptyDirsInMarkdownOnlyMode() throws {
        _ = try write("keep/inside.md")
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("empty"),
            withIntermediateDirectories: true
        )
        _ = try write("only-txt/other.txt")

        let b = FolderBrowser()
        b.open(rootURL: tmp)
        let names = (b.root?.children ?? []).map(\.name)
        XCTAssertEqual(names, ["keep"])
    }

    func testRecursiveChildrenLoaded() throws {
        _ = try write("nested/deep/inside.md")

        let b = FolderBrowser()
        b.open(rootURL: tmp)
        let nested = b.root?.children?.first
        XCTAssertEqual(nested?.name, "nested")
        let deep = nested?.children?.first
        XCTAssertEqual(deep?.name, "deep")
        XCTAssertEqual(deep?.children?.first?.name, "inside.md")
    }

    func testCloseClearsRoot() throws {
        _ = try write("a.md")
        let b = FolderBrowser()
        b.open(rootURL: tmp)
        XCTAssertNotNil(b.root)
        b.close()
        XCTAssertNil(b.root)
        XCTAssertFalse(b.isOpen)
    }

    func testToggleShowAllRebuilds() throws {
        _ = try write("a.md")
        _ = try write("b.txt")
        let b = FolderBrowser()
        b.open(rootURL: tmp)
        XCTAssertEqual(b.root?.children?.count, 1)
        b.showAllFiles = true
        XCTAssertEqual(b.root?.children?.count, 2)
    }
}
