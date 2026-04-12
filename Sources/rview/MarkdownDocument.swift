import Foundation
import Combine
import Ink

@MainActor
final class MarkdownDocument: ObservableObject {
    @Published private(set) var html: String = welcomeHTML
    @Published private(set) var displayTitle: String = "rview"

    private var currentURL: URL?
    private var watcher: FileWatcher?
    private let parser = MarkdownParser()

    func open(url: URL) {
        currentURL = url
        displayTitle = url.lastPathComponent
        render()
        watcher = FileWatcher(url: url) { [weak self] in
            Task { @MainActor in self?.render() }
        }
    }

    func reload() { render() }

    private func render() {
        guard let url = currentURL else { return }
        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            html = parser.html(from: source)
        } catch {
            html = "<pre>Failed to read \(url.path): \(error.localizedDescription)</pre>"
        }
    }

}

private let welcomeHTML = """
<h1>rview</h1>
<p>A light, native markdown viewer for macOS.</p>
<p>Open a file with <code>⌘O</code> or drop one onto the window.</p>
"""
