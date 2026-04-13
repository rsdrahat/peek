import XCTest
@testable import peek

final class AppDelegateTests: XCTestCase {
    func testNoArgsReturnsNil() {
        XCTAssertNil(AppDelegate.fileURL(fromArgs: ["/path/to/peek"]))
    }

    func testFirstNonFlagArgIsUsed() {
        let url = AppDelegate.fileURL(fromArgs: ["peek", "README.md"])
        XCTAssertEqual(url?.lastPathComponent, "README.md")
    }

    func testFlagsAreSkipped() {
        let url = AppDelegate.fileURL(fromArgs: ["peek", "--verbose", "-x", "file.md"])
        XCTAssertEqual(url?.lastPathComponent, "file.md")
    }

    func testAbsolutePathPreserved() {
        let url = AppDelegate.fileURL(fromArgs: ["peek", "/tmp/doc.md"])
        XCTAssertEqual(url?.path, "/tmp/doc.md")
    }

    func testOnlyFlagsReturnsNil() {
        XCTAssertNil(AppDelegate.fileURL(fromArgs: ["peek", "--help", "-v"]))
    }
}
