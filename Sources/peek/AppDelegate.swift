import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Buffered launch-time URL. Populated by `application:openFile:` (delivered
    // by Launch Services before `applicationDidFinishLaunching`) or falls back
    // to argv. Drained by `MainWindow.onAppear` via `consumePendingURL()`.
    //
    // Why not post via NotificationCenter at launch: SwiftUI's WindowGroup does
    // not reliably materialize the root view — and therefore register its
    // `.onReceive(.peekOpenFile)` subscriber — within one runloop tick of
    // `applicationDidFinishLaunching`. On some machines the notification fired
    // before there was anyone to receive it, and the window sat on the welcome
    // HTML. Buffer + pull eliminates the race.
    static var pendingURL: URL?
    static var didFinishLaunching = false

    static func consumePendingURL() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
    }

    /// Testable core of `applicationDidFinishLaunching`.
    static func handleDidFinishLaunching(args: [String] = CommandLine.arguments) {
        didFinishLaunching = true
        if pendingURL == nil {
            pendingURL = fileURL(fromArgs: args)
        }
    }

    /// Testable core of `application(_:openFile:)`.
    @discardableResult
    static func handleOpenFile(_ filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if didFinishLaunching {
            post(url: url)
        } else {
            pendingURL = url
        }
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
