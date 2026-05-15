import Foundation

/// Renders a JSONL document — one JSON value per line — as a virtualized
/// list of expandable rows. Each row is a `.json-node`, reusing the
/// tree renderer's lazy `<template>` machinery so the full per-line tree
/// only materializes when the user clicks to expand.
///
/// v0.5 cuts at `maxFullyMaterializedLines` lines. Above that, the head of
/// the file renders fully and a banner explains the rest. True streaming
/// (mmap'd byte-offset index, lazy per-line parse driven by scroll) is a
/// follow-up — the common JSONL case (logs, agent traces, training records)
/// fits well under 50k lines.
public struct JSONLRenderer {
    public static let maxFullyMaterializedLines = 50_000

    /// One source line + the parse outcome. Holds the raw string for error
    /// display and the parsed value (if any) so we don't reparse to render.
    public struct LineEntry: Equatable {
        public let lineNumber: Int           // 1-based
        public let raw: String
        public let parsed: JSONValue?
        public let error: JSONParseError?
    }

    /// Parse a JSONL source into ordered entries.
    public static func parse(_ source: String) -> [LineEntry] {
        var entries: [LineEntry] = []
        var lineNumber = 0
        source.enumerateLines { line, _ in
            lineNumber += 1
            // Skip blank lines — common in hand-edited JSONL.
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return }
            do {
                let value = try JSONParser.parse(line)
                entries.append(LineEntry(lineNumber: lineNumber, raw: line,
                                         parsed: value, error: nil))
            } catch let e as JSONParseError {
                entries.append(LineEntry(lineNumber: lineNumber, raw: line,
                                         parsed: nil, error: e))
            } catch {
                let unknown = JSONParseError(line: lineNumber, column: 1,
                                             message: "parse failed")
                entries.append(LineEntry(lineNumber: lineNumber, raw: line,
                                         parsed: nil, error: unknown))
            }
        }
        return entries
    }

    public static func render(entries: [LineEntry], totalLines: Int) -> String {
        var out = "<div class=\"jsonl-tree\">"
        if entries.count >= maxFullyMaterializedLines && totalLines > entries.count {
            out += banner(rendered: entries.count, total: totalLines)
        }
        for entry in entries.prefix(maxFullyMaterializedLines) {
            out += renderLine(entry)
        }
        out += "</div>"
        // Reuse the tree toggle/copy/search script once for the whole page.
        out += JSONTreeRenderer.script
        return out
    }

    private static func banner(rendered: Int, total: Int) -> String {
        """
        <div class="jsonl-banner">
          Showing first \(rendered) of \(total) lines.
          The rest is on disk — open a slice in your editor to inspect.
        </div>
        """
    }

    private static func renderLine(_ entry: LineEntry) -> String {
        var out = ""
        if let err = entry.error {
            out += #"<div class="jsonl-row jsonl-row-error" data-line="\#(entry.lineNumber)">"#
            out += #"<div class="json-line">"#
            out += "<span class=\"jsonl-line-number\">\(entry.lineNumber)</span>"
            out += #"<span class="json-toggle-spacer"></span>"#
            out += "<span class=\"jsonl-error-msg\">parse error (col \(err.column)): \(escape(err.message))</span>"
            out += "</div>"
            out += "</div>"
            return out
        }
        guard let value = entry.parsed else { return out }

        let preview = compactPreview(value)
        switch value {
        case .object, .array:
            // Containers: collapsible row whose full tree lives in a template
            // and materializes on first expand.
            out += #"<div class="jsonl-row json-node collapsed json-lazy" data-kind="jsonl-line" data-line="\#(entry.lineNumber)">"#
            out += #"<div class="json-line">"#
            out += "<span class=\"jsonl-line-number\">\(entry.lineNumber)</span>"
            out += #"<span class="json-toggle" data-toggle>▾</span>"#
            out += "<span class=\"jsonl-preview\">\(escape(preview))</span>"
            out += "</div>"
            out += "<template class=\"json-deferred-children\">"
            // The full tree HTML for the line's value. Path is rooted at this
            // line's value — the line number is the "outer scope", so paths
            // start fresh per line.
            out += JSONTreeRenderer.renderHTML(value)
            out += "</template>"
            out += "</div>"
        case .string, .number, .bool, .null:
            // Scalars: inline, no expand affordance.
            out += #"<div class="jsonl-row" data-line="\#(entry.lineNumber)">"#
            out += #"<div class="json-line">"#
            out += "<span class=\"jsonl-line-number\">\(entry.lineNumber)</span>"
            out += #"<span class="json-toggle-spacer"></span>"#
            out += "<span class=\"jsonl-preview\">\(escape(preview))</span>"
            out += "</div>"
            out += "</div>"
        }
        return out
    }

    // MARK: - Compact single-line preview
    //
    // For the row header. ~120 chars max; truncated with an ellipsis. Keeps
    // structure visible without overwhelming the row strip.

    public static let previewMaxLength = 120

    public static func compactPreview(_ v: JSONValue, max: Int = previewMaxLength) -> String {
        var out = ""
        appendCompact(v, into: &out, max: max)
        if out.count > max {
            return String(out.prefix(max - 1)) + "…"
        }
        return out
    }

    private static func appendCompact(_ v: JSONValue, into out: inout String, max: Int) {
        if out.count >= max { return }
        switch v {
        case .object(let members):
            out += "{"
            for (i, m) in members.enumerated() {
                if out.count >= max { out += "…"; break }
                if i > 0 { out += ", " }
                out += "\(m.key): "
                appendCompact(m.value, into: &out, max: max)
            }
            if out.count < max { out += "}" }
        case .array(let items):
            out += "["
            for (i, item) in items.enumerated() {
                if out.count >= max { out += "…"; break }
                if i > 0 { out += ", " }
                appendCompact(item, into: &out, max: max)
            }
            if out.count < max { out += "]" }
        case .string(let s):
            let display = s.count > 30 ? String(s.prefix(30)) + "…" : s
            out += "\"\(display)\""
        case .number(.int(let i)): out += "\(i)"
        case .number(.double(let d)): out += "\(d)"
        case .bool(let b): out += b ? "true" : "false"
        case .null: out += "null"
        }
    }

    private static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for c in s {
            switch c {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(c)
            }
        }
        return out
    }
}
