import XCTest
@testable import peek

final class DocumentKindTests: XCTestCase {
    func testMarkdownExtensions() {
        XCTAssertEqual(URL(fileURLWithPath: "/x/foo.md").peekDocumentKind, .markdown)
        XCTAssertEqual(URL(fileURLWithPath: "/x/foo.markdown").peekDocumentKind, .markdown)
        XCTAssertEqual(URL(fileURLWithPath: "/x/foo.mdown").peekDocumentKind, .markdown)
        XCTAssertEqual(URL(fileURLWithPath: "/x/foo.mkd").peekDocumentKind, .markdown)
    }

    func testJSONExtension() {
        XCTAssertEqual(URL(fileURLWithPath: "/x/data.json").peekDocumentKind, .json)
        XCTAssertEqual(URL(fileURLWithPath: "/x/data.JSON").peekDocumentKind, .json,
                       "extension match must be case-insensitive")
    }

    func testJSONLExtensions() {
        XCTAssertEqual(URL(fileURLWithPath: "/x/data.jsonl").peekDocumentKind, .jsonl)
        XCTAssertEqual(URL(fileURLWithPath: "/x/data.ndjson").peekDocumentKind, .jsonl,
                       "ndjson is the same wire format as jsonl; route to the same viewer")
    }

    func testUnknownExtension() {
        XCTAssertEqual(URL(fileURLWithPath: "/x/data.bin").peekDocumentKind, .unknown)
        XCTAssertEqual(URL(fileURLWithPath: "/x/data").peekDocumentKind, .unknown,
                       "no extension → unknown")
    }

    func testCompoundExtensionsAreNotStripped() {
        // foo.json.bak should NOT route as JSON — extension is .bak.
        XCTAssertEqual(URL(fileURLWithPath: "/x/foo.json.bak").peekDocumentKind, .unknown)
    }
}
