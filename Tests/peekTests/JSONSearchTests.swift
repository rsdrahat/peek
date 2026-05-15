import XCTest
@testable import peek

/// JSON tree search relies on WKWebView's native find for highlight + scroll.
/// What we own — and what these tests cover — is the JS surface that
/// materializes lazy <template> children and expands collapsed ancestors so
/// the native find can see matches that would otherwise be hidden.
final class JSONSearchTests: XCTestCase {
    func testRendererExposesPrepareForSearchFunction() {
        let html = JSONTreeRenderer.render(.object([JSONMember("a", .null)]))
        XCTAssertTrue(html.contains("peekJSONPrepareForSearch"),
                      "search-prep entry point must be defined on window")
        XCTAssertTrue(html.contains("window.peekJSONPrepareForSearch ="),
                      "function must be attached to window so WKWebView can call it")
    }

    func testPrepareForSearchAcceptsAQueryArgument() {
        let html = JSONTreeRenderer.render(.array([.null]))
        XCTAssertTrue(html.contains("peekJSONPrepareForSearch = function(query)"),
                      "function must accept the query so we only materialize matching templates")
    }

    func testPrepareWalksLazyTemplatesAndExpandsCollapsed() {
        let html = JSONTreeRenderer.render(.array([.null]))
        XCTAssertTrue(html.contains("template.json-deferred-children"),
                      "prep must iterate lazy template wrappers")
        XCTAssertTrue(html.contains(".json-node.collapsed"),
                      "prep must also expand non-lazy collapsed nodes whose subtree contains a hit")
    }

    func testPrepareReentrantForNestedLazyTemplates() {
        // Newly-materialized templates may themselves contain more lazy
        // templates. The prep function must loop until quiescent.
        let html = JSONTreeRenderer.render(.array([.null]))
        XCTAssertTrue(html.contains("while (changed)"),
                      "prep must loop so deeper lazy templates also materialize on match")
    }

    func testRendererSetsKeyAndValueClassesSearchCanLatchOn() {
        // The find pass is plain-text — relies on WKWebView's native find.
        // Just confirm key + value text is present in the DOM (not inside
        // attributes only).
        let html = JSONTreeRenderer.render(.object([
            JSONMember("findme", .string("needle"))
        ]))
        // Keys are wrapped in literal quotes inside the span (JSON-y display)
        XCTAssertTrue(html.contains("\"findme\""), "key text must be in DOM body")
        XCTAssertTrue(html.contains("needle"), "value text must be in DOM body")
    }
}
