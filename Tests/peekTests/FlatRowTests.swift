import XCTest
@testable import peek

@MainActor
final class FlatRowTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-flat-tests-\(UUID().uuidString)", isDirectory: true)
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

    private func mkdir(_ rel: String) throws {
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent(rel),
            withIntermediateDirectories: true
        )
    }

    private func tree(showAllFiles: Bool = false) -> [FolderNode] {
        FolderBrowser.listChildren(of: tmp, showAllFiles: showAllFiles)
    }

    // MARK: - Lazy listing

    func testListChildrenIsOneLevelOnly() throws {
        try write("a/inside.md")
        let children = tree()
        let a = children.first { $0.name == "a" }
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.isDirectory)
        // Lazy: subdirectory children are not populated until explicitly loaded.
        XCTAssertNil(a!.children)
    }

    func testIgnoredDirNamesSkippedInMdMode() throws {
        try write("node_modules/lib/x.md")
        try write("__pycache__/x.md")
        try write("docs/readme.md")
        let names = tree(showAllFiles: false).map(\.name)
        XCTAssertEqual(names, ["docs"])
    }

    func testIgnoredDirNamesShownWhenShowAllFiles() throws {
        try write("node_modules/lib/x.md")
        try write("docs/readme.md")
        let names = tree(showAllFiles: true).map(\.name)
        XCTAssertTrue(names.contains("node_modules"))
        XCTAssertTrue(names.contains("docs"))
    }

    func testDotDirectoriesAlwaysHidden() throws {
        try write(".git/config")
        try write("docs/readme.md")
        let allFiles = tree(showAllFiles: true).map(\.name)
        XCTAssertFalse(allFiles.contains(".git"))
    }

    // MARK: - Flatten with lazy children

    func testFlattenCollapsedOnlyShowsTopLevel() throws {
        try write("a/inside.md")
        try write("b.md")

        let rows = FlatRow.flatten(children: tree(), expanded: [])
        XCTAssertEqual(rows.map(\.node.name), ["a", "b.md"])
        XCTAssertEqual(rows.map(\.depth), [0, 0])
    }

    func testFlattenExpandedResolvesViaLoadedChildren() throws {
        try write("a/inside.md")
        try write("b.md")

        let children = tree()
        let aURL = children.first { $0.name == "a" }!.url
        // Simulate the sidebar loading a's children on expand.
        let loaded: [URL: [FolderNode]] = [
            aURL: FolderBrowser.listChildren(of: aURL, showAllFiles: false)
        ]
        let rows = FlatRow.flatten(
            children: children,
            expanded: [aURL],
            loadedChildren: loaded
        )
        XCTAssertEqual(rows.map(\.node.name), ["a", "inside.md", "b.md"])
        XCTAssertEqual(rows.map(\.depth), [0, 1, 0])
    }

    func testFlattenExpandedWithoutLoadedChildrenIsEmptySubtree() throws {
        try write("a/inside.md")
        let children = tree()
        let aURL = children.first { $0.name == "a" }!.url
        // Expanded but no cache entry yet → renders just the directory itself.
        let rows = FlatRow.flatten(children: children, expanded: [aURL])
        XCTAssertEqual(rows.map(\.node.name), ["a"])
    }

    // MARK: - FolderBrowser.loadChildren cache

    func testLoadChildrenPopulatesCache() throws {
        try write("a/inside.md")
        let browser = FolderBrowser()
        browser.open(rootURL: tmp)
        let aURL = browser.root!.children!.first { $0.name == "a" }!.url
        browser.loadChildren(at: aURL)
        XCTAssertEqual(browser.loadedChildren[aURL]?.map(\.name), ["inside.md"])
    }

    func testRefreshAppliesNewChildrenOffMain() async throws {
        try write("a.md")
        let browser = FolderBrowser()
        browser.open(rootURL: tmp)
        XCTAssertEqual(browser.root?.children?.count, 1)

        // refresh() is async (off-main). The new file isn't reflected
        // synchronously — we have to await the apply.
        try write("b.md")
        browser.refresh()
        try await waitUntilTrue { browser.root?.children?.count == 2 }
        let names = (browser.root?.children ?? []).map(\.name).sorted()
        XCTAssertEqual(names, ["a.md", "b.md"])
    }

    func testRefreshAfterCloseIsNoop() async throws {
        try write("a.md")
        let browser = FolderBrowser()
        browser.open(rootURL: tmp)
        browser.close()
        // Stale dispatched work must not resurrect state on a closed browser.
        browser.refresh()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(browser.root)
        XCTAssertEqual(browser.loadedChildren.count, 0)
    }

    func testRebuildDropsCacheForRemovedDirectories() async throws {
        try mkdir("gone")
        let browser = FolderBrowser()
        browser.open(rootURL: tmp)
        let goneURL = browser.root!.children!.first { $0.name == "gone" }!.url
        browser.loadChildren(at: goneURL)
        XCTAssertNotNil(browser.loadedChildren[goneURL])

        try FileManager.default.removeItem(at: goneURL)
        browser.refresh()  // off-main; wait for the result to apply
        try await waitUntilTrue { browser.loadedChildren[goneURL] == nil }
        XCTAssertNil(browser.loadedChildren[goneURL])
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
