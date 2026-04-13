import XCTest
@testable import peek

final class BreadcrumbTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/tmp/notes")

    func testFileAtRootProducesRootAndFile() {
        let segs = BreadcrumbPath.segments(root: root, current: root.appendingPathComponent("foo.md"))
        XCTAssertEqual(segs.map(\.name), ["notes", "foo.md"])
        XCTAssertEqual(segs.map(\.isFile), [false, true])
    }

    func testNestedFileProducesIntermediateSegments() {
        let current = root.appendingPathComponent("a/b/c.md")
        let segs = BreadcrumbPath.segments(root: root, current: current)
        XCTAssertEqual(segs.map(\.name), ["notes", "a", "b", "c.md"])
        XCTAssertEqual(segs.last?.isFile, true)
        XCTAssertEqual(segs.dropLast().map(\.isFile), [false, false, false])
    }

    func testSegmentURLsAreCumulative() {
        let current = root.appendingPathComponent("a/b.md")
        let segs = BreadcrumbPath.segments(root: root, current: current)
        XCTAssertEqual(segs[0].url.path, "/tmp/notes")
        XCTAssertEqual(segs[1].url.path, "/tmp/notes/a")
        XCTAssertEqual(segs[2].url.path, "/tmp/notes/a/b.md")
    }

    func testCurrentOutsideRootReturnsEmpty() {
        let outside = URL(fileURLWithPath: "/var/elsewhere/x.md")
        XCTAssertTrue(BreadcrumbPath.segments(root: root, current: outside).isEmpty)
    }

    func testCurrentEqualsRootReturnsEmpty() {
        XCTAssertTrue(BreadcrumbPath.segments(root: root, current: root).isEmpty)
    }

    func testSiblingPathDoesNotMatchPrefix() {
        // /tmp/notes-other should not be treated as inside /tmp/notes
        let sibling = URL(fileURLWithPath: "/tmp/notes-other/x.md")
        XCTAssertTrue(BreadcrumbPath.segments(root: root, current: sibling).isEmpty)
    }
}
