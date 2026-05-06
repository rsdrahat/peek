import XCTest
@testable import peek

final class CommandPaletteTests: XCTestCase {
    func testPaletteItemEquatable() {
        let a = PaletteItem(id: "/x.md", title: "x.md")
        let b = PaletteItem(id: "/x.md", title: "x.md")
        let c = PaletteItem(id: "/y.md", title: "y.md")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testPaletteItemDefaultsSubtitleAndIcon() {
        let item = PaletteItem(id: "/a.md", title: "a.md")
        XCTAssertNil(item.subtitle)
        XCTAssertEqual(item.systemImage, "doc.text")
    }

    func testPaletteItemCarriesPathThroughId() {
        // The activation handler in MainWindow reconstructs a file URL from
        // PaletteItem.id, so the id contract is "absolute file path" for
        // file-mode results. Lock that.
        let item = PaletteItem(id: "/Users/x/notes/y.md", title: "y.md", subtitle: "/Users/x/notes")
        let url = URL(fileURLWithPath: item.id)
        XCTAssertEqual(url.path, "/Users/x/notes/y.md")
        XCTAssertEqual(url.lastPathComponent, "y.md")
    }
}
