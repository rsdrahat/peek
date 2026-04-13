import XCTest
@testable import peek

/// Integration test for FileWatcher. Skipped under CI where fs events can be flaky.
final class FileWatcherTests: XCTestCase {
    func testWatcherFiresOnWrite() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil,
                      "FileWatcher integration test skipped on CI")

        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-watcher-\(UUID().uuidString).md")
        try "initial".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let fired = expectation(description: "watcher fires")
        fired.assertForOverFulfill = false
        let watcher = FileWatcher(url: tmp) { fired.fulfill() }
        XCTAssertNotNil(watcher)

        // Give DispatchSource a moment to arm.
        Thread.sleep(forTimeInterval: 0.05)
        try "updated".write(to: tmp, atomically: false, encoding: .utf8)

        wait(for: [fired], timeout: 2.0)
        _ = watcher  // keep alive through wait
    }
}
