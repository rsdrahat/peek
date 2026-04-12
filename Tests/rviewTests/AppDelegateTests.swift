import XCTest
@testable import rview

final class AppDelegateTests: XCTestCase {
    func testNoArgsReturnsNil() {
        XCTAssertNil(AppDelegate.fileURL(fromArgs: ["/path/to/rview"]))
    }

    func testFirstNonFlagArgIsUsed() {
        let url = AppDelegate.fileURL(fromArgs: ["rview", "README.md"])
        XCTAssertEqual(url?.lastPathComponent, "README.md")
    }

    func testFlagsAreSkipped() {
        let url = AppDelegate.fileURL(fromArgs: ["rview", "--verbose", "-x", "file.md"])
        XCTAssertEqual(url?.lastPathComponent, "file.md")
    }

    func testAbsolutePathPreserved() {
        let url = AppDelegate.fileURL(fromArgs: ["rview", "/tmp/doc.md"])
        XCTAssertEqual(url?.path, "/tmp/doc.md")
    }

    func testOnlyFlagsReturnsNil() {
        XCTAssertNil(AppDelegate.fileURL(fromArgs: ["rview", "--help", "-v"]))
    }
}
