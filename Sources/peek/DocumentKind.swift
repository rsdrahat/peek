import Foundation

/// What kind of document a URL points at, decided by extension. v1 trusts
/// the extension and does not content-sniff — a `.md` file with JSON in it
/// is rendered as Markdown, deliberately. Adding sniffing later is cheaper
/// than rolling it back if it ever picks the wrong viewer.
public enum DocumentKind: Equatable, Sendable {
    case markdown
    case json
    case jsonl
    case unknown
}

public extension URL {
    /// `DocumentKind` derived from the path extension. Lowercased; trims
    /// the leading dot. Multiple extensions are not stripped — a file
    /// `foo.json.bak` is `.unknown`, not `.json`.
    var peekDocumentKind: DocumentKind {
        switch pathExtension.lowercased() {
        case "md", "markdown", "mdown", "mkd": return .markdown
        case "json": return .json
        case "jsonl", "ndjson": return .jsonl
        default: return .unknown
        }
    }
}
