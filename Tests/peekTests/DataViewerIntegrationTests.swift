import XCTest
@testable import peek

/// End-to-end integration tests for the v0.5 data viewer pipeline.
/// Each test feeds a real file through `MarkdownDocument.open(url:)` (the
/// single dispatcher) and asserts on the published `html` to confirm every
/// piece of the pipeline is wired:
///
///   AppDelegate → LaunchURLBuffer → MainWindow → MarkdownDocument.open
///     → DocumentKind dispatch → JSONParser / JSONLRenderer
///       → JSONTreeRenderer (tree, lazy templates, keypath attrs, search prep)
///
/// Anything that breaks in that chain should surface here.
@MainActor
final class DataViewerIntegrationTests: XCTestCase {
    func testOpenJSONFileRendersFullTreeWithAllSurfaces() throws {
        let url = try writeTempFile("good.json", contents: """
        {"name": "peek", "stats": {"tests": 200, "files": 30}, "tags": ["light", "native"]}
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = MarkdownDocument()
        doc.open(url: url)

        let html = doc.html
        // Format-detect (PR 2)
        XCTAssertTrue(html.contains("peek-data-badge"), "PR 2: summary chip not present")
        XCTAssertTrue(html.contains(">JSON<"), "PR 2: JSON badge text missing")
        // Tree render (PR 3)
        XCTAssertTrue(html.contains("json-tree"), "PR 3: tree wrapper missing")
        XCTAssertTrue(html.contains("data-toggle"), "PR 3: toggle script absent")
        XCTAssertTrue(html.contains("json-string"), "PR 3: string value class missing")
        // Virtualization (PR 4) — small object stays eager; no template here
        // but the JS hook must still be present
        XCTAssertTrue(html.contains("materializeIfLazy"), "PR 4: lazy materialization helper missing")
        // Key-path copy (PR 5)
        XCTAssertTrue(html.contains("data-path=\"name\""), "PR 5: dotted path attribute missing")
        XCTAssertTrue(html.contains("data-jsonpointer=\"/name\""), "PR 5: pointer attribute missing")
        XCTAssertTrue(html.contains("data-jsonpointer=\"/tags/0\""), "PR 5: array-index pointer missing")
        XCTAssertTrue(html.contains("copyToClipboard"), "PR 5: clipboard helper missing")
        // Search (PR 6)
        XCTAssertTrue(html.contains("window.peekJSONPrepareForSearch"), "PR 6: search prep entry missing")
    }

    func testOpenJSONLFileRendersRowsWithAllSurfaces() throws {
        let url = try writeTempFile("logs.jsonl", contents: """
        {"id": 1, "event": "open"}
        {"id": 2, "event": "click", "x": 5}
        bad json line
        {"id": 4, "event": "save"}
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = MarkdownDocument()
        doc.open(url: url)
        let html = doc.html

        XCTAssertTrue(html.contains(">JSONL<"), "JSONL badge missing")
        XCTAssertTrue(html.contains("jsonl-line-number"), "line-number gutter missing")
        XCTAssertTrue(html.contains("data-line=\"1\""))
        XCTAssertTrue(html.contains("data-line=\"4\""), "later lines must still render after a bad line")
        XCTAssertTrue(html.contains("jsonl-row-error"), "parse-error row missing for the bad line")
        // Toggle script attached exactly once (deduped at the page level)
        let scriptCount = html.components(separatedBy: "window.peekJSONPrepareForSearch").count - 1
        XCTAssertEqual(scriptCount, 1, "tree script must be emitted once for a JSONL page, not per row")
    }

    func testOpenInvalidJSONShowsInlineErrorNotCrash() throws {
        let url = try writeTempFile("bad.json", contents: #"{"unterminated:"#)
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = MarkdownDocument()
        doc.open(url: url)
        XCTAssertTrue(doc.html.contains("JSON parse error"))
        XCTAssertTrue(doc.html.contains("line <strong>1</strong>"))
    }

    func testMarkdownDispatchStillWorks() throws {
        let url = try writeTempFile("note.md", contents: "# Hello\n\nThis is *peek*.")
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = MarkdownDocument()
        doc.open(url: url)
        // Markdown render path should still produce h1 + em — confirms the
        // v0.5 dispatch didn't break the original viewer.
        XCTAssertTrue(doc.html.contains("<h1"))
        XCTAssertTrue(doc.html.contains("<em>"))
        XCTAssertFalse(doc.html.contains("json-tree"))
    }

    func testUnknownExtensionFallsBackToMarkdown() throws {
        // Per DocumentKind: unknown extensions route to markdown, not JSON.
        // Important so a `.log` or `.txt` file doesn't accidentally try to
        // tree-render and 404.
        let url = try writeTempFile("data.bin", contents: "hello\nworld")
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = MarkdownDocument()
        doc.open(url: url)
        XCTAssertFalse(doc.html.contains("json-tree"))
    }

    // MARK: - End-to-end perf budget
    //
    // The full pipeline — read + parse + tree-render — for a 10MB JSON
    // should stay well under the safety budget. Release on M-series is
    // typically <200ms; CI macOS-14 in debug is the worst case.

    func testEndToEnd10MBJSONOpensUnderBudget() throws {
        // Synth a ~10MB JSON: array of small objects.
        var s = "["
        s.reserveCapacity(12_000_000)
        let unit = #"{"id":12345,"name":"row","tags":["a","b","c"],"score":3.14,"flag":true}"#
        let count = 100_000
        for i in 0..<count {
            if i > 0 { s.append(",") }
            s.append(unit)
        }
        s.append("]")
        let url = try writeTempFile("big.json", contents: s)
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = MarkdownDocument()
        let t0 = CFAbsoluteTimeGetCurrent()
        doc.open(url: url)
        let elapsed = CFAbsoluteTimeGetCurrent() - t0

        // Above the lazy threshold and the maxFullyMaterializedSize → stub
        // path engages, so html stays small even though source is 10MB.
        XCTAssertGreaterThan(doc.html.count, 100)
        XCTAssertLessThan(elapsed, 30.0, "10MB end-to-end exceeded safety budget — \(elapsed)s")
        if elapsed > 2.0 {
            print("⚠️ 10MB end-to-end took \(elapsed)s — over the 2s soft budget")
        }
    }

    // MARK: - Helpers

    private func writeTempFile(_ name: String, contents: String) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-integration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(name)
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
