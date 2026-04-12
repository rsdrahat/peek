import SwiftUI
import AppKit

@main
struct RviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .frame(minWidth: 480, minHeight: 360)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { appDelegate.openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Reload") { NotificationCenter.default.post(name: .rviewReload, object: nil) }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Toggle Theme") { NotificationCenter.default.post(name: .rviewToggleTheme, object: nil) }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .textEditing) {
                Button("Find…") { NotificationCenter.default.post(name: .rviewFindOpen, object: nil) }
                    .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { NotificationCenter.default.post(name: .rviewZoomIn, object: nil) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { NotificationCenter.default.post(name: .rviewZoomOut, object: nil) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { NotificationCenter.default.post(name: .rviewZoomReset, object: nil) }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let rviewReload = Notification.Name("rview.reload")
    static let rviewToggleTheme = Notification.Name("rview.toggleTheme")
    static let rviewOpenFile = Notification.Name("rview.openFile")
    static let rviewFindOpen = Notification.Name("rview.findOpen")
    static let rviewZoomIn = Notification.Name("rview.zoomIn")
    static let rviewZoomOut = Notification.Name("rview.zoomOut")
    static let rviewZoomReset = Notification.Name("rview.zoomReset")
}
