import XCTest
import SwiftUI
@testable import peek

/// Tests for the v0.4.2 hot-reload + memory work:
///   - `jsStringLiteral` must produce a JS-safe quoted literal for any body
///     content. This is the boundary that protects against the swap path
///     breaking out of its string container.
///   - `shell()` continues to embed the cached resources (we removed the
///     per-call disk read; verify resources still arrive in output).
final class MarkdownWebViewHotReloadTests: XCTestCase {
    func testJSStringLiteralRoundtripsSimple() {
        let lit = MarkdownWebView.jsStringLiteral("hello")
        XCTAssertEqual(lit, "\"hello\"")
    }

    func testJSStringLiteralEscapesQuotesAndBackslashes() {
        let lit = MarkdownWebView.jsStringLiteral("a \"quoted\" \\ slash")
        // JSON encodes " as \" and \ as \\
        XCTAssertEqual(lit, "\"a \\\"quoted\\\" \\\\ slash\"")
    }

    func testJSStringLiteralEscapesNewlines() {
        let lit = MarkdownWebView.jsStringLiteral("line1\nline2")
        XCTAssertEqual(lit, "\"line1\\nline2\"")
    }

    func testJSStringLiteralHandlesScriptInjectionAttempts() {
        // The whole point of swapping via JSON-encoded innerHTML is that user
        // markdown can't escape its container. </script> is fine *inside* an
        // innerHTML string because the browser isn't doing script-tag parsing
        // there. What matters is no JS-syntax break.
        let payload = "</script><script>alert(1)</script>"
        let lit = MarkdownWebView.jsStringLiteral(payload)
        // Must still be a valid JS string literal — bracket-stripped output
        // starts and ends with " and contains no unescaped " or newline.
        XCTAssertTrue(lit.hasPrefix("\""))
        XCTAssertTrue(lit.hasSuffix("\""))
        let inner = String(lit.dropFirst().dropLast())
        XCTAssertFalse(inner.contains("\n"))
        // No bare double-quote inside the literal.
        var i = inner.startIndex
        var prevWasBackslash = false
        while i < inner.endIndex {
            let c = inner[i]
            if c == "\"" {
                XCTAssertTrue(prevWasBackslash, "unescaped quote at \(i) in \(inner)")
            }
            prevWasBackslash = (c == "\\") && !prevWasBackslash
            i = inner.index(after: i)
        }
    }

    func testShellStillEmbedsHighlightJS() {
        // We cache the resource string statically; the shell must still
        // include it so syntax highlighting works on first load.
        let html = MarkdownWebView.shell(body: "<p>x</p>", theme: .light)
        XCTAssertTrue(html.contains("hljs.highlightAll();"),
                      "highlight.js bootstrap script missing from shell")
    }

    func testShellRespectsTheme() {
        let light = MarkdownWebView.shell(body: "", theme: .light)
        let dark = MarkdownWebView.shell(body: "", theme: .dark)
        XCTAssertTrue(light.contains("data-theme=\"light\""))
        XCTAssertTrue(dark.contains("data-theme=\"dark\""))
    }
}
