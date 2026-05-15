import XCTest
@testable import peek

final class JSONTreeRendererTests: XCTestCase {
    // MARK: - Container chrome

    func testEmptyObjectRendersWithoutChevron() {
        let html = JSONTreeRenderer.render(.object([]))
        XCTAssertTrue(html.contains("json-tree"))
        XCTAssertTrue(html.contains("{}"))
        // The JS toggle script always ships at the bottom; check that no
        // visible chevron UI element was emitted by looking for the toggle's
        // span class, not the attribute (which appears in the script too).
        XCTAssertFalse(html.contains(#"class="json-toggle""#),
                       "empty containers should not emit a clickable chevron")
    }

    func testEmptyArrayRendersWithoutChevron() {
        let html = JSONTreeRenderer.render(.array([]))
        XCTAssertTrue(html.contains("[]"))
        XCTAssertFalse(html.contains(#"class="json-toggle""#))
    }

    func testObjectGetsChevronAndSummary() {
        let html = JSONTreeRenderer.render(.object([JSONMember("a", .null), JSONMember("b", .null)]))
        XCTAssertTrue(html.contains("data-toggle"))
        XCTAssertTrue(html.contains("2 keys"))
        XCTAssertTrue(html.contains("json-bracket-open"))
        XCTAssertTrue(html.contains("json-close-line"))
    }

    func testArrayGetsChevronAndSummary() {
        let html = JSONTreeRenderer.render(.array([.null, .null, .null]))
        XCTAssertTrue(html.contains("data-toggle"))
        XCTAssertTrue(html.contains("3 items"))
    }

    func testSingleItemSummaryUsesSingular() {
        let one = JSONTreeRenderer.render(.object([JSONMember("a", .null)]))
        XCTAssertTrue(one.contains("1 key"), "singular when count is 1")
        let oneArr = JSONTreeRenderer.render(.array([.null]))
        XCTAssertTrue(oneArr.contains("1 item"))
    }

    // MARK: - Leaf rendering + escaping

    func testStringEscapesHTMLAndKeepsQuotes() {
        let html = JSONTreeRenderer.render(.string("<b>&\"ok\""))
        XCTAssertTrue(html.contains("json-string"))
        XCTAssertTrue(html.contains("&lt;b&gt;&amp;&quot;ok&quot;"))
        // Wrapped in literal quotes for JSON-like display
        XCTAssertTrue(html.contains("\"&lt;b&gt;"))
    }

    func testKeysAreEscapedAndQuoted() {
        let html = JSONTreeRenderer.render(.object([JSONMember("a<b>", .null)]))
        XCTAssertTrue(html.contains("a&lt;b&gt;"))
        XCTAssertTrue(html.contains("json-key"))
    }

    func testNumberClassesAndValues() {
        XCTAssertTrue(JSONTreeRenderer.render(.number(.int(42))).contains(">42<"))
        XCTAssertTrue(JSONTreeRenderer.render(.number(.double(3.14))).contains("3.14"))
        XCTAssertTrue(JSONTreeRenderer.render(.number(.int(42))).contains("json-number"))
    }

    func testBoolAndNullClasses() {
        XCTAssertTrue(JSONTreeRenderer.render(.bool(true)).contains("json-bool"))
        XCTAssertTrue(JSONTreeRenderer.render(.bool(true)).contains(">true<"))
        XCTAssertTrue(JSONTreeRenderer.render(.null).contains("json-null"))
    }

    // MARK: - Nesting + comma placement

    func testNestedObjectIndentsViaChildrenWrapper() {
        let nested = JSONValue.object([
            JSONMember("outer", .object([JSONMember("inner", .number(.int(1)))]))
        ])
        let html = JSONTreeRenderer.render(nested)
        // Two json-node divs (outer + inner), one wrapped inside the other's json-children
        let nodeCount = html.components(separatedBy: "<div class=\"json-node\"").count - 1
        XCTAssertEqual(nodeCount, 2)
    }

    func testCommaOmittedOnLastChild() {
        let html = JSONTreeRenderer.render(.array([
            .number(.int(1)), .number(.int(2)), .number(.int(3))
        ]))
        // Two commas for three items — last has none.
        let commas = html.components(separatedBy: "json-comma").count - 1
        XCTAssertEqual(commas, 2)
    }

    // MARK: - Stub for huge containers

    func testHugeContainerRendersStubInsteadOfFullTree() {
        let many = (0..<10_000).map { JSONMember("k\($0)", .number(.int(Int64($0)))) }
        let html = JSONTreeRenderer.render(.object(many))
        XCTAssertTrue(html.contains("json-node-stub"))
        XCTAssertTrue(html.contains("10000 keys"))
        // Stub should not include 10k key labels.
        let keyCount = html.components(separatedBy: "json-key").count - 1
        XCTAssertLessThan(keyCount, 5,
                          "stubbed huge container must not materialize per-key markup")
    }

    // MARK: - JS toggle script

    func testIncludesToggleScript() {
        let html = JSONTreeRenderer.render(.object([JSONMember("a", .null)]))
        XCTAssertTrue(html.contains("<script>"))
        XCTAssertTrue(html.contains("data-toggle"))
        XCTAssertTrue(html.contains("ev.altKey"),
                      "Option+click cascade must be present")
    }
}
