import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Self.fileURL(fromArgs: CommandLine.arguments) {
            NotificationCenter.default.post(name: .rviewOpenFile, object: url)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        NotificationCenter.default.post(name: .rviewOpenFile, object: URL(fileURLWithPath: filename))
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            .plainText,
        ]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .rviewOpenFile, object: url)
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
