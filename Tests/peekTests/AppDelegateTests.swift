import XCTest
@testable import peek

final class AppDelegateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppDelegate.resetState()
    }

    override func tearDown() {
        AppDelegate.resetState()
        super.tearDown()
    }

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

    // MARK: - post(url:) dir-vs-file branching
    //
    // Guards the v0.3.3 regression: `peek .` only reaches the sidebar if
    // directory URLs land in the .peekOpenFolder branch. If anyone collapses
    // the isDir check or swaps the notification names, the sidebar stops
    // opening for directory args.

    func testPostEmitsFolderNotificationForDirectory() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let (fired, other) = captureNotifications(folder: .peekOpenFolder, file: .peekOpenFile) {
            AppDelegate.post(url: dir)
        }
        XCTAssertEqual(fired, dir)
        XCTAssertNil(other, "directory URL must not emit .peekOpenFile")
    }

    func testPostEmitsFileNotificationForRegularFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let doc = dir.appendingPathComponent("note.md")
        try "hello".write(to: doc, atomically: true, encoding: .utf8)

        let (fired, other) = captureNotifications(folder: .peekOpenFile, file: .peekOpenFolder) {
            AppDelegate.post(url: doc)
        }
        XCTAssertEqual(fired, doc)
        XCTAssertNil(other, "file URL must not emit .peekOpenFolder")
    }

    // MARK: - Launch-time URL buffering
    //
    // Guards the 0.3.3 bug where `peek foo.md` showed the welcome screen on
    // some machines: `applicationDidFinishLaunching` posted the .peekOpenFile
    // notification on the next runloop tick, which was not reliably after
    // SwiftUI's WindowGroup had wired up its subscriber. Now the URL is
    // buffered and MainWindow drains it on .onAppear.

    func testConsumePendingURLReturnsAndClears() {
        AppDelegate.pendingURL = URL(fileURLWithPath: "/tmp/a.md")
        XCTAssertEqual(AppDelegate.consumePendingURL()?.path, "/tmp/a.md")
        XCTAssertNil(AppDelegate.consumePendingURL(),
                     "second consume must return nil — MainWindow.onAppear can fire more than once")
    }

    func testConsumePendingURLWhenEmptyReturnsNil() {
        XCTAssertNil(AppDelegate.consumePendingURL())
    }

    func testOpenFileBeforeLaunchBuffersIntoPendingURL() {
        // Launch Services delivers the file BEFORE didFinishLaunching.
        // Nothing subscribes yet, so posting would be lost — buffer instead.
        let sawFile = expectationInverted(for: .peekOpenFile)
        let sawFolder = expectationInverted(for: .peekOpenFolder)
        AppDelegate.handleOpenFile("/tmp/early.md")
        XCTAssertEqual(AppDelegate.pendingURL?.path, "/tmp/early.md")
        wait(for: [sawFile, sawFolder], timeout: 0.05)
    }

    func testOpenFileAfterLaunchPostsImmediatelyAndDoesNotBuffer() {
        AppDelegate.handleDidFinishLaunching(args: ["peek"])
        let observer = NotificationCapture(name: .peekOpenFile)
        AppDelegate.handleOpenFile("/tmp/warm.md")
        XCTAssertEqual(observer.receivedURL?.path, "/tmp/warm.md")
        XCTAssertNil(AppDelegate.pendingURL,
                     "warm path must not buffer — notification is the source of truth")
    }

    func testDidFinishLaunchingFallsBackToArgv() {
        AppDelegate.handleDidFinishLaunching(args: ["peek", "/tmp/from-argv.md"])
        XCTAssertEqual(AppDelegate.consumePendingURL()?.path, "/tmp/from-argv.md")
    }

    func testDidFinishLaunchingPreservesOpenFileURLOverArgv() {
        // Cold start via `open -a peek foo.md`: openFile fires first with
        // foo.md, then didFinishLaunching fires with argv that doesn't
        // include foo.md. The openFile URL must win.
        AppDelegate.handleOpenFile("/tmp/from-openfile.md")
        AppDelegate.handleDidFinishLaunching(args: ["peek"])
        XCTAssertEqual(AppDelegate.consumePendingURL()?.path, "/tmp/from-openfile.md")
    }

    func testDidFinishLaunchingWithNoArgsAndNoOpenFileLeavesPendingNil() {
        AppDelegate.handleDidFinishLaunching(args: ["peek"])
        XCTAssertNil(AppDelegate.consumePendingURL())
    }

    func testFullColdStartSequenceDeliversURLToDrainer() throws {
        // End-to-end simulation of a cold start:
        //   1. LS calls application:openFile: (early)
        //   2. applicationDidFinishLaunching fires (no post — unreliable race)
        //   3. MainWindow.onAppear drains and re-posts through post(url:)
        // Assert the final .peekOpenFile notification carries the right URL.
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let doc = dir.appendingPathComponent("cold.md")
        try "hi".write(to: doc, atomically: true, encoding: .utf8)

        AppDelegate.handleOpenFile(doc.path)                           // step 1
        AppDelegate.handleDidFinishLaunching(args: ["peek"])          // step 2

        let observer = NotificationCapture(name: .peekOpenFile)
        if let url = AppDelegate.consumePendingURL() {                 // step 3
            AppDelegate.post(url: url)
        }
        XCTAssertEqual(observer.receivedURL, doc)
    }

    func expectationInverted(for name: Notification.Name) -> XCTestExpectation {
        let e = expectation(forNotification: name, object: nil, handler: { _ in true })
        e.isInverted = true
        return e
    }

    private func makeTempDir() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peek-appdelegate-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// One-shot synchronous observer. `post(url:)` posts synchronously, so by
    /// the time the test reads `receivedURL` after triggering a post, the
    /// value is already set.
    final class NotificationCapture {
        private(set) var receivedURL: URL?
        private var token: NSObjectProtocol?
        init(name: Notification.Name) {
            token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
                self?.receivedURL = note.object as? URL
            }
        }
        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }

    /// Synchronously capture which of two notifications fires during `block`.
    /// `post(url:)` posts synchronously, so no async wait is needed.
    private func captureNotifications(
        folder expected: Notification.Name,
        file unexpected: Notification.Name,
        during block: () -> Void
    ) -> (fired: URL?, other: URL?) {
        var fired: URL?
        var other: URL?
        let center = NotificationCenter.default
        let a = center.addObserver(forName: expected, object: nil, queue: nil) {
            fired = $0.object as? URL
        }
        let b = center.addObserver(forName: unexpected, object: nil, queue: nil) {
            other = $0.object as? URL
        }
        defer {
            center.removeObserver(a)
            center.removeObserver(b)
        }
        block()
        return (fired, other)
    }
}
