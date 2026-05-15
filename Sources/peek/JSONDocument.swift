import Foundation
import Combine

/// JSON viewer document. Reads a `.json` file, parses it, and publishes an
/// HTML render of the result (or a parse-error block). Parallel structure to
/// `MarkdownDocument` so MainWindow can hold either as state and feed the
/// same `MarkdownWebView` shell.
///
/// v0.5 format-detect PR ships a static pretty-printed render. The
/// collapsible tree UI lands in the tree-render PR — keeping this minimal
/// for the routing slice.
@MainActor
final class JSONDocument: ObservableObject {
    @Published private(set) var html: String = ""
    @Published private(set) var displayTitle: String = "peek"
    @Published private(set) var currentURL: URL?
    @Published private(set) var parsedValue: JSONValue?
    @Published private(set) var parseError: JSONParseError?

    private var watcher: FileWatcher?

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
            parsedValue = nil
            parseError = nil
            return
        }
        do {
            let data = try Data(contentsOf: url)
            do {
                let value = try JSONParser.parse(data: data)
                parsedValue = value
                parseError = nil
                let source = String(data: data, encoding: .utf8) ?? ""
                html = Self.previewHTML(value: value, source: source)
            } catch let e as JSONParseError {
                parsedValue = nil
                parseError = e
                let source = String(data: data, encoding: .utf8) ?? ""
                html = Self.parseErrorHTML(error: e, source: source)
            }
        } catch {
            parsedValue = nil
            parseError = nil
            html = Self.readErrorHTML(url: url, error: error)
        }
    }

    /// "We parsed it OK" rendering: summary chip + collapsible tree.
    static func previewHTML(value: JSONValue, source: String) -> String {
        _ = source  // retained for potential raw-toggle in a later PR
        let summary = summaryLine(for: value)
        return """
        <section class="peek-data-summary">
          <span class="peek-data-badge">JSON</span>
          <span class="peek-data-summary-text">\(escape(summary))</span>
        </section>
        \(JSONTreeRenderer.render(value))
        """
    }

    static func parseErrorHTML(error: JSONParseError, source: String) -> String {
        // Show the offending line with a caret under the column.
        let lines = source.components(separatedBy: "\n")
        let lineIdx = max(0, error.line - 1)
        let context: String
        if lineIdx < lines.count {
            let bad = lines[lineIdx]
            let caret = String(repeating: " ", count: max(0, error.column - 1)) + "^"
            context = "\(escape(bad))\n\(caret)"
        } else {
            context = ""
        }
        return """
        <div class="peek-error">
          <h1>JSON parse error</h1>
          <p>line <strong>\(error.line)</strong>, column <strong>\(error.column)</strong>: \(escape(error.message))</p>
          <pre class="peek-error-context"><code>\(context)</code></pre>
        </div>
        """
    }

    static func summaryLine(for v: JSONValue) -> String {
        switch v {
        case .object(let m): return "object with \(m.count) keys"
        case .array(let a):  return "array of \(a.count) elements"
        case .string(let s):
            let preview = s.count > 64 ? String(s.prefix(64)) + "…" : s
            return "string: \"\(preview)\""
        case .number(.int(let i)): return "number: \(i)"
        case .number(.double(let d)): return "number: \(d)"
        case .bool(let b): return "boolean: \(b)"
        case .null: return "null"
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
        htmlEscape(s)
    }

    /// HTML-escape — exposed so the markdown dispatcher and other callers
    /// don't reinvent it. Same minimal escape: `&`, `<`, `>` — peek's HTML
    /// is rendered by our own pipeline, never re-served, so quoting `"`
    /// and `'` isn't needed.
    static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
