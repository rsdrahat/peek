import XCTest
@testable import peek

final class KeyPathTests: XCTestCase {
    typealias Seg = JSONTreeRenderer.PathSegment

    // MARK: - Dotted form

    func testDottedEmptyPathIsEmpty() {
        XCTAssertEqual(JSONTreeRenderer.dottedPath([]), "")
    }

    func testDottedSimpleKey() {
        XCTAssertEqual(JSONTreeRenderer.dottedPath([.key("foo")]), "foo")
    }

    func testDottedNestedKeys() {
        XCTAssertEqual(JSONTreeRenderer.dottedPath([.key("foo"), .key("bar")]), "foo.bar")
    }

    func testDottedArrayIndex() {
        XCTAssertEqual(JSONTreeRenderer.dottedPath([.key("foo"), .index(0)]), "foo[0]")
    }

    func testDottedMixed() {
        let p: [Seg] = [.key("a"), .index(2), .key("b"), .index(7)]
        XCTAssertEqual(JSONTreeRenderer.dottedPath(p), "a[2].b[7]")
    }

    func testDottedWeirdKeyUsesBracketForm() {
        // Spaces, dashes, dots → not a simple identifier → bracket-quoted.
        XCTAssertEqual(JSONTreeRenderer.dottedPath([.key("my key")]), "[\"my key\"]")
        XCTAssertEqual(JSONTreeRenderer.dottedPath([.key("a-b")]), "[\"a-b\"]")
        XCTAssertEqual(JSONTreeRenderer.dottedPath([.key("a.b")]), "[\"a.b\"]")
    }

    func testDottedKeyStartingWithDigitUsesBracketForm() {
        XCTAssertEqual(JSONTreeRenderer.dottedPath([.key("1foo")]), "[\"1foo\"]")
    }

    func testDottedKeyWithQuoteIsEscaped() {
        XCTAssertEqual(JSONTreeRenderer.dottedPath([.key("a\"b")]), "[\"a\\\"b\"]")
    }

    // MARK: - JSON Pointer (RFC 6901)

    func testPointerEmpty() {
        XCTAssertEqual(JSONTreeRenderer.jsonPointer([]), "")
    }

    func testPointerSimple() {
        XCTAssertEqual(JSONTreeRenderer.jsonPointer([.key("foo")]), "/foo")
        XCTAssertEqual(JSONTreeRenderer.jsonPointer([.key("foo"), .key("bar")]), "/foo/bar")
    }

    func testPointerArrayIndex() {
        XCTAssertEqual(JSONTreeRenderer.jsonPointer([.key("foo"), .index(0)]), "/foo/0")
    }

    func testPointerEscapesSlash() {
        // RFC 6901: `/` in a key becomes `~1`
        XCTAssertEqual(JSONTreeRenderer.jsonPointer([.key("a/b")]), "/a~1b")
    }

    func testPointerEscapesTilde() {
        // RFC 6901: `~` becomes `~0`
        XCTAssertEqual(JSONTreeRenderer.jsonPointer([.key("a~b")]), "/a~0b")
    }

    func testPointerEscapesTildeBeforeSlash() {
        // Per RFC 6901 the order matters: replace `~` first, then `/`.
        // "~/" → "~0/" → "~0~1"
        XCTAssertEqual(JSONTreeRenderer.jsonPointer([.key("~/")]), "/~0~1")
    }

    // MARK: - HTML emission

    func testRendererEmitsDataPathOnLeafLines() {
        let html = JSONTreeRenderer.render(.object([
            JSONMember("hello", .string("world")),
        ]))
        XCTAssertTrue(html.contains("data-path=\"hello\""))
        XCTAssertTrue(html.contains("data-jsonpointer=\"/hello\""))
    }

    func testRendererEmitsDataPathOnNestedLeaf() {
        let html = JSONTreeRenderer.render(.object([
            JSONMember("a", .array([.number(.int(1)), .number(.int(2))])),
        ]))
        XCTAssertTrue(html.contains("data-path=\"a[0]\""))
        XCTAssertTrue(html.contains("data-jsonpointer=\"/a/0\""))
        XCTAssertTrue(html.contains("data-path=\"a[1]\""))
    }

    func testRendererSkipsDataPathOnRoot() {
        // The whole-document path (empty) gives no useful copy target.
        let html = JSONTreeRenderer.render(.string("just a string"))
        XCTAssertFalse(html.contains("data-path=\"\""),
                       "root path should not get an empty data-path attribute")
    }

    func testRendererToggleScriptIncludesClipboardCopy() {
        let html = JSONTreeRenderer.render(.object([JSONMember("a", .null)]))
        XCTAssertTrue(html.contains("copyToClipboard"))
        XCTAssertTrue(html.contains("showToast"))
        XCTAssertTrue(html.contains("data-jsonpointer"),
                      "Option+click branch must read the jsonpointer attribute")
    }
}
