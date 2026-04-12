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
        }
    }
}

extension Notification.Name {
    static let rviewReload = Notification.Name("rview.reload")
    static let rviewToggleTheme = Notification.Name("rview.toggleTheme")
    static let rviewOpenFile = Notification.Name("rview.openFile")
}
