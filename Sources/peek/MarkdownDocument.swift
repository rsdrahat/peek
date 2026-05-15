import Foundation
import Combine

@MainActor
final class MarkdownDocument: ObservableObject {
    @Published private(set) var html: String = welcomeHTML
    @Published private(set) var displayTitle: String = "peek"
    @Published private(set) var currentURL: URL?
    @Published private(set) var toc: [TOCEntry] = []

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
        switch url.peekDocumentKind {
        case .json:
            renderJSON(url: url)
        case .jsonl:
            renderJSONL(url: url)
        case .markdown, .unknown:
            renderMarkdown(url: url)
        }
    }

    private func renderMarkdown(url: URL) {
        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            let result = renderer.render(source)
            html = result.html
            toc = result.toc
            displayTitle = url.lastPathComponent
        } catch {
            html = Self.readErrorHTML(url: url, error: error)
            toc = []
        }
    }

    private func renderJSON(url: URL) {
        toc = []
        do {
            let data = try Data(contentsOf: url)
            let source = String(data: data, encoding: .utf8) ?? ""
            do {
                let value = try JSONParser.parse(data: data)
                html = JSONDocument.previewHTML(value: value, source: source)
            } catch let e as JSONParseError {
                html = JSONDocument.parseErrorHTML(error: e, source: source)
            }
            displayTitle = url.lastPathComponent
        } catch {
            html = Self.readErrorHTML(url: url, error: error)
        }
    }

    private func renderJSONL(url: URL) {
        toc = []
        // Placeholder: real JSONL renderer lands in the jsonl-line-virtualization
        // bead. For now, show the source verbatim so users at least see their
        // data and the file is "open" (sidebar / breadcrumb / watching work).
        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            let line = source.split(separator: "\n", omittingEmptySubsequences: true).count
            html = """
            <section class="peek-data-summary">
              <span class="peek-data-badge">JSONL</span>
              <span class="peek-data-summary-text">\(line) lines — full viewer coming in v0.5</span>
            </section>
            <pre class="peek-data-source"><code>\(JSONDocument.htmlEscape(source))</code></pre>
            """
            displayTitle = url.lastPathComponent
        } catch {
            html = Self.readErrorHTML(url: url, error: error)
        }
    }

    private static func missingFileHTML(url: URL) -> String {
        """
        <div class="peek-error">
        <h1>File not found</h1>
        <p>The file has been moved or deleted.</p>
        <p class="peek-error-path"><code>\(escape(url.path))</code></p>
        <p class="peek-error-hint">Press <kbd>⌘R</kbd> to retry, or <kbd>⌘O</kbd> to open another file.</p>
        </div>
        """
    }

    private static func readErrorHTML(url: URL, error: Error) -> String {
        """
        <div class="peek-error">
        <h1>Failed to read file</h1>
        <p class="peek-error-path"><code>\(escape(url.path))</code></p>
        <pre>\(escape(error.localizedDescription))</pre>
        <p class="peek-error-hint">Press <kbd>⌘R</kbd> to retry.</p>
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
<h1>peek</h1>
<p>A light, native markdown viewer for macOS.</p>
<p>Open a file with <code>⌘O</code> or drop one onto the window.</p>
"""
