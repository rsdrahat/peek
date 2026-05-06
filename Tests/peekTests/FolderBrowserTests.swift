import XCTest
@testable import peek

@MainActor
final class FolderBrowserTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-folder-tests-\(UUID().uuidString)", isDirectory: true)
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

    func testEmptyDirectoriesShownInMarkdownOnlyMode() throws {
        // Lazy loading means we no longer recurse on open to decide
        // whether a directory is "worth showing". Matches Finder's
        // behavior — empty dirs are visible, the user can expand.
        _ = try write("keep/inside.md")
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("empty"),
            withIntermediateDirectories: true
        )
        _ = try write("only-txt/other.txt")

        let b = FolderBrowser()
        b.open(rootURL: tmp)
        let names = Set((b.root?.children ?? []).map(\.name))
        XCTAssertEqual(names, ["empty", "keep", "only-txt"])
    }

    func testNestedDirectoriesAreLazy() throws {
        _ = try write("nested/deep/inside.md")

        let b = FolderBrowser()
        b.open(rootURL: tmp)
        let nested = b.root?.children?.first
        XCTAssertEqual(nested?.name, "nested")
        // Lazy: children below the root are nil until loadChildren is called.
        XCTAssertNil(nested?.children)

        b.loadChildren(at: nested!.url)
        let deep = b.loadedChildren[nested!.url]?.first
        XCTAssertEqual(deep?.name, "deep")
        XCTAssertNil(deep?.children)
    }

    func testIgnoredDirectoriesSkipped() throws {
        _ = try write("node_modules/lib.md")
        _ = try write("__pycache__/x.md")
        _ = try write("docs/readme.md")
        let b = FolderBrowser()
        b.open(rootURL: tmp)
        let names = Set((b.root?.children ?? []).map(\.name))
        XCTAssertEqual(names, ["docs"])
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
