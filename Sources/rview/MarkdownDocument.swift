import Foundation
import Combine

@MainActor
final class MarkdownDocument: ObservableObject {
    @Published private(set) var html: String = welcomeHTML
    @Published private(set) var displayTitle: String = "rview"
    @Published private(set) var currentURL: URL?

    private var watcher: FileWatcher?

    private let renderer = Renderer()

    func open(url: URL) {
        currentURL = url
        displayTitle = url.lastPathComponent
        render()
        watcher = FileWatcher(url: url) { [weak self] in
            Task { @MainActor in self?.onWatcherFired() }
        }
    }

    func reload() { render() }

    private func onWatcherFired() {
        guard let url = currentURL else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            html = Self.missingFileHTML(url: url)
            displayTitle = url.lastPathComponent + " (missing)"
            return
        }
        render()
    }

    private func render() {
        guard let url = currentURL else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            html = Self.missingFileHTML(url: url)
            displayTitle = url.lastPathComponent + " (missing)"
            return
        }
        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            html = renderer.html(from: source)
            displayTitle = url.lastPathComponent
        } catch {
            html = Self.readErrorHTML(url: url, error: error)
        }
    }

    private static func missingFileHTML(url: URL) -> String {
        """
        <div class="rview-error">
        <h1>File not found</h1>
        <p>The file has been moved or deleted.</p>
        <p class="rview-error-path"><code>\(escape(url.path))</code></p>
        <p class="rview-error-hint">Press <kbd>⌘R</kbd> to retry, or <kbd>⌘O</kbd> to open another file.</p>
        </div>
        """
    }

    private static func readErrorHTML(url: URL, error: Error) -> String {
        """
        <div class="rview-error">
        <h1>Failed to read file</h1>
        <p class="rview-error-path"><code>\(escape(url.path))</code></p>
        <pre>\(escape(error.localizedDescription))</pre>
        <p class="rview-error-hint">Press <kbd>⌘R</kbd> to retry.</p>
        </div>
        """
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private let welcomeHTML = """
<h1>rview</h1>
<p>A light, native markdown viewer for macOS.</p>
<p>Open a file with <code>⌘O</code> or drop one onto the window.</p>
"""
