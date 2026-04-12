import XCTest
@testable import rview

@MainActor
final class MarkdownDocumentTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rview-doc-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testOpenExistingFileRendersHTML() throws {
        let url = tmp.appendingPathComponent("a.md")
        try "# Hello\n\nWorld.".write(to: url, atomically: true, encoding: .utf8)

        let doc = MarkdownDocument()
        doc.open(url: url)

        XCTAssertTrue(doc.html.contains("<h1>Hello</h1>"), doc.html)
        XCTAssertTrue(doc.html.contains("World."))
        XCTAssertEqual(doc.displayTitle, "a.md")
    }

    func testOpenMissingFileProducesErrorHTML() throws {
        let url = tmp.appendingPathComponent("nope.md")
        let doc = MarkdownDocument()
        doc.open(url: url)

        XCTAssertTrue(doc.html.contains("Failed to read"), doc.html)
        XCTAssertFalse(doc.html.isEmpty)
    }

    func testReloadPicksUpDiskChanges() throws {
        let url = tmp.appendingPathComponent("b.md")
        try "# First".write(to: url, atomically: true, encoding: .utf8)
        let doc = MarkdownDocument()
        doc.open(url: url)
        XCTAssertTrue(doc.html.contains("First"))

        try "# Second".write(to: url, atomically: true, encoding: .utf8)
        doc.reload()
        XCTAssertTrue(doc.html.contains("Second"))
        XCTAssertFalse(doc.html.contains("First"))
    }

    func testOpenSwitchesCurrentFile() throws {
        let a = tmp.appendingPathComponent("a.md")
        let b = tmp.appendingPathComponent("b.md")
        try "# A".write(to: a, atomically: true, encoding: .utf8)
        try "# B".write(to: b, atomically: true, encoding: .utf8)

        let doc = MarkdownDocument()
        doc.open(url: a)
        XCTAssertTrue(doc.html.contains("A"))
        doc.open(url: b)
        XCTAssertTrue(doc.html.contains("B"))
        XCTAssertEqual(doc.displayTitle, "b.md")

        // Reload should now track b, not a.
        try "# B2".write(to: b, atomically: true, encoding: .utf8)
        doc.reload()
        XCTAssertTrue(doc.html.contains("B2"))
    }
}
