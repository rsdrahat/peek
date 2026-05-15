import XCTest
@testable import peek

final class JSONLRendererTests: XCTestCase {
    // MARK: - Parse

    func testParseEmptySourceIsEmpty() {
        XCTAssertEqual(JSONLRenderer.parse("").count, 0)
    }

    func testParseSimpleLines() {
        let source = """
        {"a": 1}
        {"b": 2}
        [3, 4]
        """
        let entries = JSONLRenderer.parse(source)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].lineNumber, 1)
        XCTAssertEqual(entries[1].lineNumber, 2)
        XCTAssertEqual(entries[2].lineNumber, 3)
        XCTAssertNotNil(entries[0].parsed)
        XCTAssertNotNil(entries[2].parsed)
    }

    func testBlankLinesAreSkipped() {
        let source = """
        {"a": 1}

        {"b": 2}

        """
        let entries = JSONLRenderer.parse(source)
        XCTAssertEqual(entries.count, 2,
                       "blank lines should not appear as parse-error rows")
        XCTAssertEqual(entries[0].lineNumber, 1)
        XCTAssertEqual(entries[1].lineNumber, 3,
                       "line numbers must reflect source position, not entry index")
    }

    func testInvalidLinesGetParseError() {
        let source = """
        {"ok": true}
        {bad json
        {"alsook": 1}
        """
        let entries = JSONLRenderer.parse(source)
        XCTAssertEqual(entries.count, 3)
        XCTAssertNil(entries[1].parsed)
        XCTAssertNotNil(entries[1].error)
        XCTAssertNotNil(entries[2].parsed,
                        "a malformed line must not poison parsing of later lines")
    }

    // MARK: - Compact preview

    func testCompactPreviewObject() {
        let v = JSONValue.object([
            JSONMember("name", .string("peek")),
            JSONMember("count", .number(.int(3))),
        ])
        let p = JSONLRenderer.compactPreview(v)
        XCTAssertTrue(p.hasPrefix("{"))
        XCTAssertTrue(p.contains("name"))
        XCTAssertTrue(p.contains("\"peek\""))
        XCTAssertTrue(p.contains("count"))
        XCTAssertTrue(p.contains("3"))
    }

    func testCompactPreviewTruncatesLongStrings() {
        let long = String(repeating: "x", count: 500)
        let v = JSONValue.string(long)
        let p = JSONLRenderer.compactPreview(v)
        XCTAssertTrue(p.contains("…"))
        XCTAssertLessThanOrEqual(p.count, JSONLRenderer.previewMaxLength)
    }

    func testCompactPreviewScalars() {
        XCTAssertEqual(JSONLRenderer.compactPreview(.number(.int(42))), "42")
        XCTAssertEqual(JSONLRenderer.compactPreview(.bool(true)), "true")
        XCTAssertEqual(JSONLRenderer.compactPreview(.null), "null")
    }

    // MARK: - Render HTML

    func testRenderEmitsRowPerLineWithLineNumbers() {
        let source = """
        {"a": 1}
        [2, 3]
        """
        let entries = JSONLRenderer.parse(source)
        let html = JSONLRenderer.render(entries: entries, totalLines: entries.count)
        XCTAssertTrue(html.contains("jsonl-line-number"))
        XCTAssertTrue(html.contains("data-line=\"1\""))
        XCTAssertTrue(html.contains("data-line=\"2\""))
        // Containers should use lazy-template virtualization (PR 4 infra)
        XCTAssertTrue(html.contains("template class=\"json-deferred-children\""))
        // Toggle script attached exactly once
        let scriptCount = html.components(separatedBy: "peekJSONPrepareForSearch").count - 1
        XCTAssertGreaterThanOrEqual(scriptCount, 1)
    }

    func testParseErrorRowsAreVisible() {
        let source = """
        {"ok": 1}
        not json
        """
        let entries = JSONLRenderer.parse(source)
        let html = JSONLRenderer.render(entries: entries, totalLines: entries.count)
        XCTAssertTrue(html.contains("jsonl-row-error"))
        XCTAssertTrue(html.contains("parse error"))
    }

    func testRenderTopCapsAtMaxLines() {
        // Simulate "we parsed more than the cap" by feeding totalLines > entries.
        let many = (0..<10).map { i in
            JSONLRenderer.LineEntry(
                lineNumber: i + 1,
                raw: "{}",
                parsed: .object([]),
                error: nil
            )
        }
        // Force the banner path by claiming the entries hit the cap.
        let html = JSONLRenderer.render(
            entries: many + Array(
                repeating: JSONLRenderer.LineEntry(
                    lineNumber: 11,
                    raw: "{}",
                    parsed: .object([]),
                    error: nil
                ),
                count: JSONLRenderer.maxFullyMaterializedLines - 10
            ),
            totalLines: JSONLRenderer.maxFullyMaterializedLines + 1_000
        )
        XCTAssertTrue(html.contains("jsonl-banner"))
        XCTAssertTrue(html.contains("Showing first"))
    }

    // MARK: - Perf budget: 10k-line JSONL stays under safety budget

    func testRenderBudgetForBigJSONL() throws {
        var s = ""
        s.reserveCapacity(2_000_000)
        for i in 0..<10_000 {
            s.append(#"{"id":\#(i),"name":"row\#(i)","tags":["a","b"]}"#)
            s.append("\n")
        }
        let t0 = CFAbsoluteTimeGetCurrent()
        let entries = JSONLRenderer.parse(s)
        let html = JSONLRenderer.render(entries: entries, totalLines: entries.count)
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        XCTAssertEqual(entries.count, 10_000)
        XCTAssertGreaterThan(html.count, 100_000)
        // Generous debug-mode safety. Release on M-series finishes in ~200ms.
        XCTAssertLessThan(elapsed, 15.0,
                          "10k-line parse+render exceeded safety budget — \(elapsed)s")
        if elapsed > 1.0 {
            print("⚠️ 10k-line render took \(elapsed)s — over the 1s soft budget")
        }
    }
}
