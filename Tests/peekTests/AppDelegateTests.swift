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
    // `application:openFile:` always writes the launch buffer (now backed
    // by the observable `LaunchURLBuffer`) — never posts a notification.
    // MainWindow observes the buffer and opens whatever lands there. This
    // closes the cold-start race where `peek <folder>` could swallow the
    // URL because `applicationDidFinishLaunching` had fired but the SwiftUI
    // notification subscribers weren't attached yet.

    func testConsumePendingURLReturnsAndClears() {
        AppDelegate.pendingURL = URL(fileURLWithPath: "/tmp/a.md")
        XCTAssertEqual(AppDelegate.consumePendingURL()?.path, "/tmp/a.md")
        XCTAssertNil(AppDelegate.consumePendingURL(),
                     "second consume must return nil — MainWindow.onAppear can fire more than once")
    }

    func testConsumePendingURLWhenEmptyReturnsNil() {
        XCTAssertNil(AppDelegate.consumePendingURL())
    }

    func testOpenFileBeforeLaunchBuffersURL() {
        // Cold start, openFile arrives before didFinishLaunching.
        let sawFile = expectationInverted(for: .peekOpenFile)
        let sawFolder = expectationInverted(for: .peekOpenFolder)
        AppDelegate.handleOpenFile("/tmp/early.md")
        XCTAssertEqual(AppDelegate.pendingURL?.path, "/tmp/early.md")
        wait(for: [sawFile, sawFolder], timeout: 0.05)
    }

    func testOpenFileAfterLaunchAlsoBuffersAndDoesNotPost() {
        // The cold-start race fix: handleOpenFile now ALWAYS buffers
        // — including after didFinishLaunching — and never posts a
        // notification directly. MainWindow observes LaunchURLBuffer
        // and reacts whenever a URL lands. Posting here would be lost
        // if the SwiftUI bridge isn't attached yet.
        AppDelegate.handleDidFinishLaunching(args: ["peek"])
        let sawFile = expectationInverted(for: .peekOpenFile)
        let sawFolder = expectationInverted(for: .peekOpenFolder)
        AppDelegate.handleOpenFile("/tmp/warm.md")
        XCTAssertEqual(AppDelegate.pendingURL?.path, "/tmp/warm.md")
        wait(for: [sawFile, sawFolder], timeout: 0.05)
    }

    func testOpenFileBufferIsObservable() {
        // MainWindow watches LaunchURLBuffer.shared via @ObservedObject.
        // Verify that handleOpenFile writes to that exact buffer.
        AppDelegate.handleDidFinishLaunching(args: ["peek"])
        AppDelegate.handleOpenFile("/tmp/observed.md")
        XCTAssertEqual(LaunchURLBuffer.shared.pendingURL?.path, "/tmp/observed.md")
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

    // Regression: cold-start ordering with didFinishLaunching firing FIRST
    // — the variant that broke `peek <folder>`. Before the fix, openFile
    // would post a notification that nothing was subscribed to. Now the URL
    // lands in the observable buffer regardless.
    func testColdStartWithDidFinishLaunchingBeforeOpenFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        AppDelegate.handleDidFinishLaunching(args: ["peek"])          // step 1: argv empty
        AppDelegate.handleOpenFile(dir.path)                          // step 2: folder arrives late

        XCTAssertEqual(AppDelegate.pendingURL?.path, dir.path,
                       "Buffer must hold the URL even when openFile fires after didFinishLaunching")
    }

    // MARK: - Modern openURLs callback (rview-w4q)
    //
    // macOS 13+ delivers file/folder args via `application(_:open: [URL])`.
    // On macOS 26 (Tahoe / Darwin 25) the legacy openFile callback may not
    // fire at all when the modern one is present, which silently dropped
    // folder args. handleOpenURL must populate the same buffer that openFile
    // does.

    func testHandleOpenURLBuffersURLDirectly() {
        let url = URL(fileURLWithPath: "/tmp/modern.md")
        XCTAssertTrue(AppDelegate.handleOpenURL(url))
        XCTAssertEqual(AppDelegate.pendingURL, url)
        XCTAssertEqual(LaunchURLBuffer.shared.pendingURL, url)
    }

    func testHandleOpenURLPreservesNonFilePathQuirks() {
        // Tilde-expansion and relative paths are the caller's job; the modern
        // callback hands us already-resolved URLs from Launch Services. We
        // store them as-is.
        let url = URL(fileURLWithPath: "/Users/foo/bar baz/with spaces.md")
        AppDelegate.handleOpenURL(url)
        XCTAssertEqual(AppDelegate.pendingURL, url,
                       "Modern callback must not normalize paths — Launch Services already did.")
    }

    func testHandleOpenURLForFolder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        AppDelegate.handleOpenURL(dir)
        XCTAssertEqual(AppDelegate.pendingURL, dir)
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
