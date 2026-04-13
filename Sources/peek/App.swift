import SwiftUI
import AppKit

@main
struct PeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .frame(minWidth: 480, minHeight: 360)
                .background(WindowAutosaveAccessor(name: "peek.main"))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 1000)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { appDelegate.openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Open Folder…") { appDelegate.openFolderPanel() }
                    .keyboardShortcut("o", modifiers: [.command, .option])
                Button("Close Folder") { NotificationCenter.default.post(name: .peekCloseFolder, object: nil) }
            }
            CommandGroup(after: .saveItem) {
                Button("Export as PDF…") { NotificationCenter.default.post(name: .peekExportPDF, object: nil) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .printItem) {
                Button("Print…") { NotificationCenter.default.post(name: .peekPrint, object: nil) }
                    .keyboardShortcut("p", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Reload") { NotificationCenter.default.post(name: .peekReload, object: nil) }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Toggle Theme") { NotificationCenter.default.post(name: .peekToggleTheme, object: nil) }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Toggle Outline") { NotificationCenter.default.post(name: .peekToggleTOC, object: nil) }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .textEditing) {
                Button("Find…") { NotificationCenter.default.post(name: .peekFindOpen, object: nil) }
                    .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { NotificationCenter.default.post(name: .peekZoomIn, object: nil) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { NotificationCenter.default.post(name: .peekZoomOut, object: nil) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { NotificationCenter.default.post(name: .peekZoomReset, object: nil) }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let peekReload = Notification.Name("peek.reload")
    static let peekToggleTheme = Notification.Name("peek.toggleTheme")
    static let peekOpenFile = Notification.Name("peek.openFile")
    static let peekOpenFolder = Notification.Name("peek.openFolder")
    static let peekCloseFolder = Notification.Name("peek.closeFolder")
    static let peekFindOpen = Notification.Name("peek.findOpen")
    static let peekZoomIn = Notification.Name("peek.zoomIn")
    static let peekZoomOut = Notification.Name("peek.zoomOut")
    static let peekZoomReset = Notification.Name("peek.zoomReset")
    static let peekPrint = Notification.Name("peek.print")
    static let peekExportPDF = Notification.Name("peek.exportPDF")
    static let peekToggleTOC = Notification.Name("peek.toggleTOC")
    static let peekScrollToAnchor = Notification.Name("peek.scrollToAnchor")
    static let peekRevealInSidebar = Notification.Name("peek.revealInSidebar")
}
