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
    /// Above this size, the container's children render into an HTML
    /// `<template>` element instead of live DOM. Templates aren't parsed
    /// into the active tree until cloned, so the initial render stays cheap
    /// even for huge files — the cost is paid on expand, per subtree.
    public static let lazyThreshold: Int = 50

    /// Hard ceiling for fully-materialized tree HTML. Above this, an array
    /// or object renders as a stub even *inside a template*, because the
    /// raw HTML string would itself be too large. The JSONL line-virtualization
    /// PR is where huge top-level arrays get a different code path.
    public static let maxFullyMaterializedSize: Int = 100_000

    /// A segment of a JSON value's path from the root. Encoded into both
    /// dotted (`foo.bar[0]`) and JSON-pointer (`/foo/bar/0`) forms on demand.
    public enum PathSegment: Equatable, Sendable {
        case key(String)
        case index(Int)
    }

    public static func render(_ value: JSONValue) -> String {
        var out = "<div class=\"json-tree\">"
        renderValue(value, key: nil, path: [], into: &out)
        out += "</div>"
        out += treeToggleScript
        return out
    }

    private static func renderValue(_ v: JSONValue, key: String?, path: [PathSegment], into out: inout String) {
        switch v {
        case .object(let members):
            renderContainer(open: "{", close: "}", count: members.count, kind: "object",
                            key: key, path: path, into: &out, renderChildren: { o in
                for (i, m) in members.enumerated() {
                    let isLast = i == members.count - 1
                    let childPath = path + [.key(m.key)]
                    renderChildLine(key: m.key, value: m.value, path: childPath, isLast: isLast, into: &o)
                }
            })
        case .array(let items):
            renderContainer(open: "[", close: "]", count: items.count, kind: "array",
                            key: key, path: path, into: &out, renderChildren: { o in
                for (i, item) in items.enumerated() {
                    let isLast = i == items.count - 1
                    let childPath = path + [.index(i)]
                    renderChildLine(key: nil, value: item, path: childPath, isLast: isLast, into: &o)
                }
            })
        case .string, .number, .bool, .null:
            // A top-level scalar — single row, no container chrome.
            out += #"<div class="json-line"\#(pathAttributes(path))>"#
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
        path: [PathSegment],
        into out: inout String,
        renderChildren: (inout String) -> Void
    ) {
        let pathAttrs = pathAttributes(path)
        // Empty containers don't get a chevron — there's nothing to expand.
        if count == 0 {
            out += #"<div class="json-line"\#(pathAttrs)>"#
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
            out += #"<div class="json-line"\#(pathAttrs)>"#
            out += #"<span class="json-toggle-spacer"></span>"#
            if let key { out += keyHTML(key) }
            out += "<span class=\"json-bracket\">\(open)</span>"
            out += " <span class=\"json-summary\">\(summaryText(kind: kind, count: count))</span> "
            out += "<span class=\"json-bracket\">\(close)</span>"
            out += "</div>"
            out += "</div>"
            return
        }

        let isLazy = count >= lazyThreshold
        // Large containers start collapsed AND their children render into
        // a <template>. Templates' content stays out of the active DOM
        // until the user expands — that's the virtualization win. Small
        // containers materialize eagerly so they're instant to interact with.
        let classes = isLazy ? "json-node collapsed json-lazy" : "json-node"

        out += #"<div class="\#(classes)" data-kind="\#(kind)">"#
        // header line — expanded form
        out += #"<div class="json-line"\#(pathAttrs)>"#
        out += #"<span class="json-toggle" data-toggle>▾</span>"#
        if let key { out += keyHTML(key) }
        out += "<span class=\"json-bracket json-bracket-open\">\(open)</span>"
        // collapsed-only inline summary + close
        out += " <span class=\"json-summary\">\(summaryText(kind: kind, count: count))</span> "
        out += "<span class=\"json-bracket json-bracket-close-inline\">\(close)</span>"
        out += "</div>"

        if isLazy {
            // Children deferred: emit inside a <template>. The toggle script
            // materializes it on first expand.
            out += #"<template class="json-deferred-children">"#
            renderChildren(&out)
            out += "</template>"
        } else {
            out += #"<div class="json-children">"#
            renderChildren(&out)
            out += "</div>"
        }
        // close line — expanded form
        out += #"<div class="json-line json-close-line">"#
        out += #"<span class="json-toggle-spacer"></span>"#
        out += "<span class=\"json-bracket\">\(close)</span>"
        out += "</div>"
        out += "</div>"
    }

    private static func renderChildLine(key: String?, value: JSONValue, path: [PathSegment], isLast: Bool, into out: inout String) {
        switch value {
        case .object, .array:
            // Nested container — recurse, key + path passed in.
            renderValue(value, key: key, path: path, into: &out)
        default:
            out += #"<div class="json-line"\#(pathAttributes(path))>"#
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

    // MARK: - Path encoding (key-path copy, rview-cvx)

    /// Dotted form: `foo.bar[0]`. Keys that aren't valid JS-identifier-ish
    /// tokens get the bracket-string form `["weird key"]`.
    public static func dottedPath(_ segments: [PathSegment]) -> String {
        var out = ""
        for seg in segments {
            switch seg {
            case .key(let k):
                if isSimpleIdentifier(k) {
                    if !out.isEmpty { out += "." }
                    out += k
                } else {
                    out += "[\"\(k.replacingOccurrences(of: "\"", with: "\\\""))\"]"
                }
            case .index(let i):
                out += "[\(i)]"
            }
        }
        return out
    }

    /// JSON-Pointer form (RFC 6901): `/foo/bar/0`. Keys escape `~`→`~0`
    /// and `/`→`~1`. An empty segment list returns the empty string, meaning
    /// "whole document" per the spec.
    public static func jsonPointer(_ segments: [PathSegment]) -> String {
        var out = ""
        for seg in segments {
            out += "/"
            switch seg {
            case .key(let k):
                out += k
                    .replacingOccurrences(of: "~", with: "~0")
                    .replacingOccurrences(of: "/", with: "~1")
            case .index(let i):
                out += "\(i)"
            }
        }
        return out
    }

    private static func isSimpleIdentifier(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        if !(first.isLetter || first == "_") { return false }
        for c in s.dropFirst() {
            if !(c.isLetter || c.isNumber || c == "_") { return false }
        }
        return true
    }

    /// Emits `data-path="..." data-jsonpointer="..."` attributes including
    /// the leading space. Empty (root) paths get no attribute pair — copying
    /// "everything" isn't useful.
    private static func pathAttributes(_ segments: [PathSegment]) -> String {
        guard !segments.isEmpty else { return "" }
        let dotted = attrEscape(dottedPath(segments))
        let pointer = attrEscape(jsonPointer(segments))
        return " data-path=\"\(dotted)\" data-jsonpointer=\"\(pointer)\""
    }

    private static func attrEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "<", with: "&lt;")
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
      function materializeIfLazy(node) {
        if (!node.classList.contains('json-lazy')) return;
        var tpl = node.querySelector(':scope > template.json-deferred-children');
        if (!tpl) { node.classList.remove('json-lazy'); return; }
        var wrap = document.createElement('div');
        wrap.className = 'json-children';
        wrap.appendChild(tpl.content.cloneNode(true));
        tpl.parentNode.insertBefore(wrap, tpl);
        tpl.remove();
        node.classList.remove('json-lazy');
      }

      // Search prep: materialize any lazy <template> whose content contains
      // the query, and expand any collapsed ancestors that contain a match.
      // After this runs, WKWebView's native find() can locate every hit.
      window.peekJSONPrepareForSearch = function(query) {
        if (!query) return;
        if (!document.querySelector('.json-tree')) return;
        var q = String(query).toLowerCase();
        // Iterate — newly-materialized templates may themselves contain
        // lazy templates with deeper matches.
        var changed = true;
        while (changed) {
          changed = false;
          var tpls = document.querySelectorAll('template.json-deferred-children');
          for (var i = 0; i < tpls.length; i++) {
            var tpl = tpls[i];
            var t = (tpl.content.textContent || '').toLowerCase();
            if (t.indexOf(q) === -1) continue;
            var node = tpl.parentNode;
            var wrap = document.createElement('div');
            wrap.className = 'json-children';
            wrap.appendChild(tpl.content.cloneNode(true));
            tpl.parentNode.insertBefore(wrap, tpl);
            tpl.remove();
            node.classList.remove('json-lazy');
            node.classList.remove('collapsed');
            changed = true;
          }
        }
        // Now expand any non-lazy collapsed nodes whose subtree contains
        // the query, so the match is visible after find() locates it.
        document.querySelectorAll('.json-node.collapsed').forEach(function(node){
          var t = (node.textContent || '').toLowerCase();
          if (t.indexOf(q) !== -1) {
            node.classList.remove('collapsed');
          }
        });
      };

      function showToast(text) {
        var t = document.getElementById('peek-toast');
        if (!t) {
          t = document.createElement('div');
          t.id = 'peek-toast';
          document.body.appendChild(t);
        }
        t.textContent = text;
        t.classList.add('show');
        if (t._h) clearTimeout(t._h);
        t._h = setTimeout(function(){ t.classList.remove('show'); }, 1400);
      }

      function copyToClipboard(text) {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text);
          return;
        }
        // Fallback for restricted contexts.
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand('copy'); } catch (e) {}
        ta.remove();
      }

      document.addEventListener('click', function(ev) {
        // Chevron toggle (incl. Option+click cascade)
        var t = ev.target.closest('[data-toggle]');
        if (t) {
          var node = t.closest('.json-node');
          if (!node) return;
          var expanding = node.classList.contains('collapsed');
          if (ev.altKey) {
            var shouldCollapse = !node.classList.contains('collapsed');
            if (!shouldCollapse) materializeIfLazy(node);
            node.classList.toggle('collapsed', shouldCollapse);
            var walk = function(root) {
              root.querySelectorAll(':scope > .json-children .json-node').forEach(function(n){
                if (!shouldCollapse) materializeIfLazy(n);
                n.classList.toggle('collapsed', shouldCollapse);
                walk(n);
              });
            };
            walk(node);
          } else {
            if (expanding) materializeIfLazy(node);
            node.classList.toggle('collapsed');
          }
          ev.stopPropagation();
          return;
        }
        // Key-path copy: click on a .json-key copies the path of its line.
        // Option+click copies the JSON-pointer form instead of dotted.
        var keyEl = ev.target.closest('.json-key');
        if (keyEl) {
          var line = keyEl.closest('.json-line');
          if (!line) return;
          var path = ev.altKey ? line.getAttribute('data-jsonpointer')
                               : line.getAttribute('data-path');
          if (!path) return;
          copyToClipboard(path);
          showToast('Copied ' + path);
          ev.stopPropagation();
        }
      });
    })();
    </script>
    """
}
