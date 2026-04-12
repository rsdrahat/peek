import Foundation
import Markdown

/// Converts markdown text to HTML using swift-markdown (cmark-gfm).
///
/// swift-markdown parses but does not emit HTML; this walker produces the
/// subset of tags our stylesheets target. Covers GFM: tables, task lists,
/// strikethrough, autolinks, fenced code with language class.
struct Renderer {
    func html(from source: String) -> String {
        let doc = Document(parsing: source, options: [.parseBlockDirectives])
        var emitter = HTMLEmitter()
        emitter.visit(doc)
        return emitter.output
    }
}

private struct HTMLEmitter: MarkupWalker {
    var output: String = ""

    mutating func defaultVisit(_ markup: Markup) {
        for child in markup.children { visit(child) }
    }

    // MARK: - Blocks

    mutating func visitDocument(_ doc: Document) {
        for child in doc.children { visit(child) }
    }

    mutating func visitHeading(_ h: Heading) {
        output += "<h\(h.level)>"
        for child in h.children { visit(child) }
        output += "</h\(h.level)>"
    }

    mutating func visitParagraph(_ p: Paragraph) {
        output += "<p>"
        for child in p.children { visit(child) }
        output += "</p>"
    }

    mutating func visitBlockQuote(_ bq: BlockQuote) {
        output += "<blockquote>"
        for child in bq.children { visit(child) }
        output += "</blockquote>"
    }

    mutating func visitCodeBlock(_ cb: CodeBlock) {
        if let lang = cb.language, !lang.isEmpty {
            output += "<pre><code class=\"language-\(Self.escape(lang))\">"
        } else {
            output += "<pre><code>"
        }
        output += Self.escape(cb.code)
        output += "</code></pre>"
    }

    mutating func visitHTMLBlock(_ block: HTMLBlock) {
        output += block.rawHTML
    }

    mutating func visitThematicBreak(_ tb: ThematicBreak) {
        output += "<hr>"
    }

    mutating func visitOrderedList(_ list: OrderedList) {
        if list.startIndex != 1 {
            output += "<ol start=\"\(list.startIndex)\">"
        } else {
            output += "<ol>"
        }
        for child in list.children { visit(child) }
        output += "</ol>"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) {
        output += "<ul>"
        for child in list.children { visit(child) }
        output += "</ul>"
    }

    mutating func visitListItem(_ item: ListItem) {
        output += "<li>"
        if let done = item.checkbox {
            let checked = done == .checked ? " checked" : ""
            output += "<input type=\"checkbox\" disabled\(checked)> "
        }
        // Tighten single-paragraph list items so they don't render as block.
        let blocks = Array(item.children)
        if blocks.count == 1, let p = blocks[0] as? Paragraph {
            for child in p.children { visit(child) }
        } else {
            for child in item.children { visit(child) }
        }
        output += "</li>"
    }

    mutating func visitTable(_ table: Table) {
        output += "<table>"
        output += "<thead><tr>"
        for (idx, cell) in table.head.cells.enumerated() {
            let alignAttr = Self.alignAttribute(table.columnAlignments, idx)
            output += "<th\(alignAttr)>"
            for child in cell.children { visit(child) }
            output += "</th>"
        }
        output += "</tr></thead>"
        output += "<tbody>"
        for row in table.body.rows {
            output += "<tr>"
            for (idx, cell) in row.cells.enumerated() {
                let alignAttr = Self.alignAttribute(table.columnAlignments, idx)
                output += "<td\(alignAttr)>"
                for child in cell.children { visit(child) }
                output += "</td>"
            }
            output += "</tr>"
        }
        output += "</tbody></table>"
    }

    // MARK: - Inlines

    mutating func visitText(_ text: Text) {
        output += Self.escape(text.string)
    }

    mutating func visitEmphasis(_ em: Emphasis) {
        output += "<em>"
        for child in em.children { visit(child) }
        output += "</em>"
    }

    mutating func visitStrong(_ s: Strong) {
        output += "<strong>"
        for child in s.children { visit(child) }
        output += "</strong>"
    }

    mutating func visitStrikethrough(_ s: Strikethrough) {
        output += "<del>"
        for child in s.children { visit(child) }
        output += "</del>"
    }

    mutating func visitInlineCode(_ code: InlineCode) {
        output += "<code>\(Self.escape(code.code))</code>"
    }

    mutating func visitInlineHTML(_ html: InlineHTML) {
        output += html.rawHTML
    }

    mutating func visitLineBreak(_: LineBreak) {
        output += "<br>"
    }

    mutating func visitSoftBreak(_: SoftBreak) {
        output += "\n"
    }

    mutating func visitLink(_ link: Link) {
        let href = link.destination.map(Self.escape) ?? ""
        output += "<a href=\"\(href)\">"
        for child in link.children { visit(child) }
        output += "</a>"
    }

    mutating func visitImage(_ img: Image) {
        let src = img.source.map(Self.escape) ?? ""
        let alt = img.plainText
        let title = img.title.map { " title=\"\(Self.escape($0))\"" } ?? ""
        output += "<img src=\"\(src)\" alt=\"\(Self.escape(alt))\"\(title)>"
    }

    // MARK: - Helpers

    private static func alignAttribute(_ aligns: [Table.ColumnAlignment?], _ idx: Int) -> String {
        guard idx < aligns.count, let a = aligns[idx] else { return "" }
        switch a {
        case .left:   return " align=\"left\""
        case .center: return " align=\"center\""
        case .right:  return " align=\"right\""
        }
    }

    private static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }
}
