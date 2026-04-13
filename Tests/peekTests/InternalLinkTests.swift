import XCTest
@testable import peek

final class InternalLinkTests: XCTestCase {
    func testFileMdIsInternal() {
        let url = URL(fileURLWithPath: "/tmp/notes/foo.md")
        XCTAssertTrue(MarkdownWebView.isInternalMarkdownLink(url))
    }

    func testFileMarkdownExtensionIsInternal() {
        let url = URL(fileURLWithPath: "/tmp/notes/foo.markdown")
        XCTAssertTrue(MarkdownWebView.isInternalMarkdownLink(url))
    }

    func testUppercaseExtensionIsInternal() {
        let url = URL(fileURLWithPath: "/tmp/notes/FOO.MD")
        XCTAssertTrue(MarkdownWebView.isInternalMarkdownLink(url))
    }

    func testHttpLinkIsExternal() {
        let url = URL(string: "https://example.com/foo.md")!
        XCTAssertFalse(MarkdownWebView.isInternalMarkdownLink(url))
    }

    func testFileNonMarkdownIsExternal() {
        let url = URL(fileURLWithPath: "/tmp/notes/image.png")
        XCTAssertFalse(MarkdownWebView.isInternalMarkdownLink(url))
    }

    func testFileNoExtensionIsExternal() {
        let url = URL(fileURLWithPath: "/tmp/notes/README")
        XCTAssertFalse(MarkdownWebView.isInternalMarkdownLink(url))
    }
}
