import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Self.fileURL(fromArgs: CommandLine.arguments) {
            Self.post(url: url)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        Self.post(url: URL(fileURLWithPath: filename))
        return true
    }

    static func post(url: URL) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
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
            NotificationCenter.default.post(name: .peekOpenFolder, object: url)
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
