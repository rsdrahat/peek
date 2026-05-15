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

    // MARK: - Stub for overwhelmingly-huge containers (above max)

    func testOverMaxContainerRendersStubInsteadOfFullTree() {
        // Above maxFullyMaterializedSize → stub (no template, no children).
        let n = JSONTreeRenderer.maxFullyMaterializedSize + 100
        let many = (0..<n).map { JSONMember("k\($0)", .number(.int(Int64($0)))) }
        let html = JSONTreeRenderer.render(.object(many))
        XCTAssertTrue(html.contains("json-node-stub"))
        XCTAssertTrue(html.contains("\(n) keys"))
        let keyCount = html.components(separatedBy: "json-key").count - 1
        XCTAssertLessThan(keyCount, 5,
                          "stubbed huge container must not materialize per-key markup")
    }

    // MARK: - Lazy templates (rview-cw1 virtualization)

    func testContainerAboveLazyThresholdUsesTemplate() {
        // Just above the lazy threshold → children should be inside a
        // <template>, not a <div class="json-children">.
        let count = JSONTreeRenderer.lazyThreshold + 5
        let items = (0..<count).map { _ in JSONValue.null }
        let html = JSONTreeRenderer.render(.array(items))
        XCTAssertTrue(html.contains("json-deferred-children"),
                      "large containers must render children inside a <template>")
        XCTAssertTrue(html.contains("json-lazy"))
        XCTAssertTrue(html.contains("class=\"json-node collapsed json-lazy\""),
                      "lazy containers must start collapsed so the template stays inert")
    }

    func testContainerBelowLazyThresholdIsEager() {
        // Small containers materialize eagerly — no template wrapper. The JS
        // toggle script always mentions these class names, so we check for
        // the structural HTML element, not the bare class string.
        let html = JSONTreeRenderer.render(.array([.number(.int(1)), .number(.int(2))]))
        XCTAssertFalse(html.contains("<template class=\"json-deferred-children\">"),
                       "small containers must not emit a deferred-children template")
        XCTAssertFalse(html.contains("\"json-node collapsed json-lazy\""),
                       "small containers must not be marked lazy")
    }

    func testToggleScriptHandlesLazyMaterialization() {
        let html = JSONTreeRenderer.render(.object([JSONMember("a", .null)]))
        XCTAssertTrue(html.contains("materializeIfLazy"),
                      "the toggle script must include lazy template materialization")
        XCTAssertTrue(html.contains("template.json-deferred-children"))
    }

    // MARK: - Virtualization perf: rendering 100k-node tree must stay snappy.
    //
    // With lazy templates, even huge containers render quickly because the
    // <template> contents stay out of the active DOM. The HTML string itself
    // still gets generated, so we measure HTML-generation time as the
    // user-facing budget — that's what blocks the first paint.

    func testRenderBudgetForBigArrayUnderHardLimit() {
        let items = (0..<10_000).map { JSONValue.number(.int(Int64($0))) }
        let t0 = CFAbsoluteTimeGetCurrent()
        let html = JSONTreeRenderer.render(.array(items))
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        XCTAssertGreaterThan(html.count, 100_000)
        // Debug-mode safety. Release on M-series renders this in ~30ms.
        XCTAssertLessThan(elapsed, 5.0,
                          "10k-element array rendering exceeded safety budget — measured \(elapsed)s")
        if elapsed > 0.3 {
            print("⚠️ 10k array render took \(elapsed)s — over the 300ms soft budget")
        }
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
