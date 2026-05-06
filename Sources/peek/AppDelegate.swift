import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Launch-time URL is held in `LaunchURLBuffer.shared.pendingURL`, which is
    // observable. MainWindow drains the initial value on .onAppear and watches
    // for subsequent changes via .onChange. This handles three cases uniformly:
    //
    // 1. Cold start, openFile fires *before* applicationDidFinishLaunching:
    //    handleOpenFile writes the buffer; .onAppear drains it.
    // 2. Cold start, openFile fires *after* applicationDidFinishLaunching:
    //    handleOpenFile writes the buffer; .onChange picks it up whenever
    //    SwiftUI gets around to materializing the view tree. Previously this
    //    posted a NotificationCenter event before the bridge was subscribed,
    //    swallowing the URL — that's the bug this commit fixes.
    // 3. Warm start (peek already running, second `peek <thing>` invocation):
    //    handleOpenFile writes the buffer; .onChange in the live MainWindow
    //    reacts.
    //
    // The static `pendingURL` and `consumePendingURL()` accessors stay for
    // backwards compatibility with existing call sites and tests; they
    // forward to the buffer.
    static var didFinishLaunching = false

    static var pendingURL: URL? {
        get { LaunchURLBuffer.shared.pendingURL }
        set { LaunchURLBuffer.shared.pendingURL = newValue }
    }

    static func consumePendingURL() -> URL? {
        let url = LaunchURLBuffer.shared.pendingURL
        LaunchURLBuffer.shared.pendingURL = nil
        return url
    }

    /// Testable core of `applicationDidFinishLaunching`.
    static func handleDidFinishLaunching(args: [String] = CommandLine.arguments) {
        didFinishLaunching = true
        if pendingURL == nil {
            pendingURL = fileURL(fromArgs: args)
        }
    }

    /// Testable core of `application(_:openFile:)`. Always writes the buffer;
    /// MainWindow observes and opens whatever lands here. Whether
    /// `didFinishLaunching` has fired and whether the SwiftUI subscriber is
    /// attached are no longer load-bearing.
    @discardableResult
    static func handleOpenFile(_ filename: String) -> Bool {
        pendingURL = URL(fileURLWithPath: filename)
        return true
    }

    /// Reset the module-global launch state. Tests only.
    static func resetState() {
        pendingURL = nil
        didFinishLaunching = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.handleDidFinishLaunching()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        Self.handleOpenFile(filename)
    }

    static func post(url: URL) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        Task { @MainActor in RecentFilesStore.shared.add(url) }
        if isDir.boolValue {
            NotificationCenter.default.post(name: .peekOpenFolder, object: url)
        } else {
            NotificationCenter.default.post(name: .peekOpenFile, object: url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Self.post(url: url)
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            .plainText,
            .folder,
        ]
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Self.post(url: url)
        }
    }

    /// Extract a file path from CLI arguments. The first non-flag argument
    /// (skipping argv[0]) is treated as a file path.
    static func fileURL(fromArgs args: [String]) -> URL? {
        for arg in args.dropFirst() where !arg.hasPrefix("-") {
            return URL(fileURLWithPath: arg)
        }
        return nil
    }
}
