import XCTest
import Ink

final class RendererTests: XCTestCase {
    func testHeadingRendersToH1() {
        let html = MarkdownParser().html(from: "# Hello")
        XCTAssertTrue(html.contains("<h1>Hello</h1>"))
    }

    func testFencedCodeBlock() {
        let html = MarkdownParser().html(from: "```\nlet x = 1\n```")
        XCTAssertTrue(html.contains("<pre>"))
        XCTAssertTrue(html.contains("let x = 1"))
    }
}
