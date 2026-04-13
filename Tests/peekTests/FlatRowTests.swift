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

    private func tree() -> [FolderNode] {
        FolderBrowser.listChildren(of: tmp, showAllFiles: false)
    }

    func testFlattenCollapsedOnlyShowsTopLevel() throws {
        try write("a/inside.md")
        try write("b.md")

        let rows = FlatRow.flatten(children: tree(), expanded: [])
        XCTAssertEqual(rows.map(\.node.name), ["a", "b.md"])
        XCTAssertEqual(rows.map(\.depth), [0, 0])
    }

    func testFlattenExpandedIncludesChildren() throws {
        try write("a/inside.md")
        try write("b.md")

        let children = tree()
        let aURL = children.first { $0.name == "a" }!.url
        let rows = FlatRow.flatten(children: children, expanded: [aURL])
        XCTAssertEqual(rows.map(\.node.name), ["a", "inside.md", "b.md"])
        XCTAssertEqual(rows.map(\.depth), [0, 1, 0])
    }

    func testFindLocatesNested() throws {
        try write("a/b/c.md")
        let children = tree()
        let c = children.first { $0.name == "a" }!.children!.first { $0.name == "b" }!.children!.first!
        let hit = FolderNode.find(url: c.url, in: children)
        XCTAssertEqual(hit?.name, "c.md")
        XCTAssertFalse(hit?.isDirectory ?? true)
    }

    func testFindMissingReturnsNil() throws {
        try write("a.md")
        let children = tree()
        XCTAssertNil(FolderNode.find(url: tmp.appendingPathComponent("nope.md"), in: children))
    }

    func testFindParentReturnsImmediateAncestor() throws {
        try write("a/b/c.md")
        let children = tree()
        let c = children.first { $0.name == "a" }!.children!.first { $0.name == "b" }!.children!.first!
        let parent = FolderNode.findParent(of: c.url, in: children, parent: nil)
        XCTAssertEqual(parent?.name, "b")
    }

    func testFindParentOfTopLevelIsNil() throws {
        try write("a.md")
        let children = tree()
        let a = children.first!
        let parent = FolderNode.findParent(of: a.url, in: children, parent: nil)
        XCTAssertNil(parent)
    }
}
