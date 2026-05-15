import XCTest
@testable import peek

@MainActor
final class JSONDocumentTests: XCTestCase {
    // MARK: - Static HTML helpers (format-detect PR surface)

    func testPreviewHTMLIncludesBadgeAndSummary() {
        let v = JSONValue.object([JSONMember("a", .number(.int(1)))])
        let html = JSONDocument.previewHTML(value: v, source: "{\"a\":1}")
        XCTAssertTrue(html.contains("peek-data-badge"))
        XCTAssertTrue(html.contains("JSON"))
        XCTAssertTrue(html.contains("object with 1 keys"))
        XCTAssertTrue(html.contains("peek-data-source"))
    }

    func testParseErrorHTMLShowsLineColumn() {
        let err = JSONParseError(line: 3, column: 5, message: "unterminated string")
        let source = "line1\nline2\n    \"oops"
        let html = JSONDocument.parseErrorHTML(error: err, source: source)
        XCTAssertTrue(html.contains("line <strong>3</strong>"))
        XCTAssertTrue(html.contains("column <strong>5</strong>"))
        XCTAssertTrue(html.contains("unterminated string"))
        // Caret should be present in the context block.
        XCTAssertTrue(html.contains("^"))
    }

    func testSummaryLineDescribesContainer() {
        XCTAssertEqual(JSONDocument.summaryLine(for: .object([])), "object with 0 keys")
        XCTAssertEqual(JSONDocument.summaryLine(for: .array([.null, .null])), "array of 2 elements")
        XCTAssertEqual(JSONDocument.summaryLine(for: .bool(true)), "boolean: true")
        XCTAssertEqual(JSONDocument.summaryLine(for: .null), "null")
    }

    func testHTMLEscape() {
        XCTAssertEqual(JSONDocument.htmlEscape("a & <b> > c"), "a &amp; &lt;b&gt; &gt; c")
    }

    // MARK: - End-to-end via JSONDocument lifecycle

    func testOpenValidJSONPopulatesParsedValue() throws {
        let url = try writeTempFile(name: "doc.json", contents: #"{"name": "peek", "count": 7}"#)
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = JSONDocument()
        doc.open(url: url)
        XCTAssertNotNil(doc.parsedValue)
        XCTAssertNil(doc.parseError)
        XCTAssertTrue(doc.html.contains("peek-data-badge"))
    }

    func testOpenInvalidJSONPopulatesParseError() throws {
        let url = try writeTempFile(name: "bad.json", contents: #"{"unterminated:"#)
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = JSONDocument()
        doc.open(url: url)
        XCTAssertNil(doc.parsedValue)
        XCTAssertNotNil(doc.parseError)
        XCTAssertTrue(doc.html.contains("JSON parse error"))
    }

    func testOpenMissingFileShowsErrorWithoutCrash() {
        let url = URL(fileURLWithPath: "/tmp/peek-does-not-exist-\(UUID().uuidString).json")
        let doc = JSONDocument()
        doc.open(url: url)
        XCTAssertTrue(doc.html.contains("File not found"))
    }

    // MARK: - Helpers

    private func writeTempFile(name: String, contents: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-jsondoc-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent(name)
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
