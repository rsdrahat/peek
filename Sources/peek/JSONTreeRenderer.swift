import Foundation

/// Renders a parsed `JSONValue` as a collapsible HTML tree. Each container
/// (object / array) becomes a `<div class="json-node">` that flips a single
/// CSS class on toggle — no per-row JS. Click the chevron to expand /
/// collapse; Option+click cascades to descendants.
///
/// v0.5 ships this un-virtualized: the whole tree is materialized in one
/// HTML pass. Virtualization (visible-row windowing for 100k-node trees)
/// arrives in the tree-virtualization PR.
public struct JSONTreeRenderer {
    /// Maximum container size we will fully materialize. Above this, we
    /// render a stub. Real virtualization replaces this in the next PR.
    public static let maxFullyMaterializedSize: Int = 5_000

    public static func render(_ value: JSONValue) -> String {
        var out = "<div class=\"json-tree\">"
        renderValue(value, key: nil, into: &out)
        out += "</div>"
        out += treeToggleScript
        return out
    }

    private static func renderValue(_ v: JSONValue, key: String?, into out: inout String) {
        switch v {
        case .object(let members):
            renderContainer(open: "{", close: "}", count: members.count, kind: "object",
                            key: key, into: &out, renderChildren: { o in
                for (i, m) in members.enumerated() {
                    let isLast = i == members.count - 1
                    renderChildLine(key: m.key, value: m.value, isLast: isLast, into: &o)
                }
            })
        case .array(let items):
            renderContainer(open: "[", close: "]", count: items.count, kind: "array",
                            key: key, into: &out, renderChildren: { o in
                for (i, item) in items.enumerated() {
                    let isLast = i == items.count - 1
                    renderChildLine(key: nil, value: item, isLast: isLast, into: &o)
                }
            })
        case .string, .number, .bool, .null:
            // A top-level scalar — single row, no container chrome.
            out += #"<div class="json-line">"#
            out += #"<span class="json-toggle-spacer"></span>"#
            if let key { out += keyHTML(key) }
            out += valueHTML(v)
            out += "</div>"
        }
    }

    /// Renders an object/array container. When collapsed, the line shows
    /// `key: { 12 keys }`; when expanded, the children render in between
    /// the open and close brackets on their own line.
    private static func renderContainer(
        open: String,
        close: String,
        count: Int,
        kind: String,
        key: String?,
        into out: inout String,
        renderChildren: (inout String) -> Void
    ) {
        // Empty containers don't get a chevron — there's nothing to expand.
        if count == 0 {
            out += #"<div class="json-line">"#
            out += #"<span class="json-toggle-spacer"></span>"#
            if let key { out += keyHTML(key) }
            out += "<span class=\"json-bracket\">\(open)\(close)</span>"
            out += "</div>"
            return
        }

        // Containers above the size cap get a stub now (full virtualization
        // in the next PR). Stub still shows the summary, so the user knows
        // the structure exists.
        if count > maxFullyMaterializedSize {
            out += #"<div class="json-node json-node-stub" data-kind="\#(kind)">"#
            out += #"<div class="json-line">"#
            out += #"<span class="json-toggle-spacer"></span>"#
            if let key { out += keyHTML(key) }
            out += "<span class=\"json-bracket\">\(open)</span>"
            out += " <span class=\"json-summary\">\(summaryText(kind: kind, count: count))</span> "
            out += "<span class=\"json-bracket\">\(close)</span>"
            out += "</div>"
            out += "</div>"
            return
        }

        out += #"<div class="json-node" data-kind="\#(kind)">"#
        // header line — expanded form
        out += #"<div class="json-line">"#
        out += #"<span class="json-toggle" data-toggle>▾</span>"#
        if let key { out += keyHTML(key) }
        out += "<span class=\"json-bracket json-bracket-open\">\(open)</span>"
        // collapsed-only inline summary + close
        out += " <span class=\"json-summary\">\(summaryText(kind: kind, count: count))</span> "
        out += "<span class=\"json-bracket json-bracket-close-inline\">\(close)</span>"
        out += "</div>"
        // children
        out += #"<div class="json-children">"#
        renderChildren(&out)
        out += "</div>"
        // close line — expanded form
        out += #"<div class="json-line json-close-line">"#
        out += #"<span class="json-toggle-spacer"></span>"#
        out += "<span class=\"json-bracket\">\(close)</span>"
        out += "</div>"
        out += "</div>"
    }

    private static func renderChildLine(key: String?, value: JSONValue, isLast: Bool, into out: inout String) {
        switch value {
        case .object, .array:
            // Nested container — recurse, key passed in.
            renderValue(value, key: key, into: &out)
        default:
            out += #"<div class="json-line">"#
            out += #"<span class="json-toggle-spacer"></span>"#
            if let key { out += keyHTML(key) }
            out += valueHTML(value)
            if !isLast { out += "<span class=\"json-comma\">,</span>" }
            out += "</div>"
        }
    }

    // MARK: - Leaf rendering

    private static func keyHTML(_ key: String) -> String {
        #"<span class="json-key">"\#(escape(key))"</span><span class="json-punct">:</span> "#
    }

    private static func valueHTML(_ v: JSONValue) -> String {
        switch v {
        case .string(let s):
            return "<span class=\"json-value json-string\">\"\(escape(s))\"</span>"
        case .number(.int(let i)):
            return "<span class=\"json-value json-number\">\(i)</span>"
        case .number(.double(let d)):
            return "<span class=\"json-value json-number\">\(formatDouble(d))</span>"
        case .bool(let b):
            return "<span class=\"json-value json-bool\">\(b ? "true" : "false")</span>"
        case .null:
            return "<span class=\"json-value json-null\">null</span>"
        case .object, .array:
            // Unreachable from a leaf path; renderChildLine recurses for containers.
            return ""
        }
    }

    private static func summaryText(kind: String, count: Int) -> String {
        switch kind {
        case "object": return count == 1 ? "1 key" : "\(count) keys"
        case "array":  return count == 1 ? "1 item" : "\(count) items"
        default:       return "\(count)"
        }
    }

    private static func formatDouble(_ d: Double) -> String {
        // Match the input style: print integers without trailing zeros where
        // possible. Foundation's default formatter is fine for v1.
        if d == d.rounded() && abs(d) < 1e16 {
            return String(format: "%.1f", d)
        }
        return String(d)
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
            default:
                if c.unicodeScalars.first.map({ $0.value < 0x20 }) ?? false {
                    out += String(format: "\\u%04x", c.unicodeScalars.first!.value)
                } else {
                    out.append(c)
                }
            }
        }
        return out
    }

    /// Tiny vanilla JS for toggling. Option+click cascades to descendants.
    /// Lives at the bottom of the rendered HTML so the DOM exists by the
    /// time it runs. Kept minimal so highlight.js isn't involved — JSON
    /// values are syntax-classified by CSS class, not by hljs.
    private static let treeToggleScript = """
    <script>
    (function(){
      document.addEventListener('click', function(ev) {
        var t = ev.target.closest('[data-toggle]');
        if (!t) return;
        var node = t.closest('.json-node');
        if (!node) return;
        if (ev.altKey) {
          var shouldCollapse = !node.classList.contains('collapsed');
          node.classList.toggle('collapsed', shouldCollapse);
          node.querySelectorAll('.json-node').forEach(function(n){
            n.classList.toggle('collapsed', shouldCollapse);
          });
        } else {
          node.classList.toggle('collapsed');
        }
        ev.stopPropagation();
      });
    })();
    </script>
    """
}
