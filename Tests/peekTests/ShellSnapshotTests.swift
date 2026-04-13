import XCTest
import SwiftUI
@testable import peek

final class ShellSnapshotTests: XCTestCase {
    func testLightShellContainsExpectedStructure() {
        let html = MarkdownWebView.shell(body: "<p>hi</p>", theme: .light)
        XCTAssertTrue(html.contains("data-theme=\"light\""))
        XCTAssertTrue(html.contains("<p>hi</p>"))
        XCTAssertTrue(html.contains("<style>"))
        XCTAssertTrue(html.contains("class=\"page\""))
    }

    func testDarkShellContainsExpectedStructure() {
        let html = MarkdownWebView.shell(body: "<p>hi</p>", theme: .dark)
        XCTAssertTrue(html.contains("data-theme=\"dark\""))
        XCTAssertTrue(html.contains("<style>"))
    }

    func testShellEscapingPreservesBodyVerbatim() {
        // We deliberately do NOT escape the body — Ink already produced safe HTML.
        // Round-trip a known block and ensure it's present unmodified.
        let body = #"<pre><code class="language-swift">let x = 1</code></pre>"#
        let html = MarkdownWebView.shell(body: body, theme: .light)
        XCTAssertTrue(html.contains(body))
    }

    func testShellLoadsSyntaxHighlighting() {
        let html = MarkdownWebView.shell(body: "x", theme: .light)
        XCTAssertTrue(html.contains("hljs.highlightAll()"),
                      "highlight.js init script missing from shell")
    }

    func testLightAndDarkDifferOnlyByTheme() {
        let light = MarkdownWebView.shell(body: "x", theme: .light)
        let dark = MarkdownWebView.shell(body: "x", theme: .dark)
        XCTAssertNotEqual(light, dark)
        // Rough shape should be the same — same number of <style> / <main> tags.
        XCTAssertEqual(
            light.components(separatedBy: "<style>").count,
            dark.components(separatedBy: "<style>").count
        )
    }
}
