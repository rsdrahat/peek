import Foundation
import Markdown

struct TOCEntry: Identifiable, Equatable {
    let id: String      // slug, also the HTML id
    let level: Int
    let text: String
}

struct RenderResult: Equatable {
    var html: String
    var toc: [TOCEntry]
}

/// Converts markdown text to HTML using swift-markdown (cmark-gfm).
///
/// Emits only the HTML subset our stylesheets target. Also collects a
/// flat Table of Contents from the document's headings.
struct Renderer {
    func render(_ source: String) -> RenderResult {
        let doc = Document(parsing: source, options: [.parseBlockDirectives])
        var emitter = HTMLEmitter()
        emitter.visit(doc)
        return RenderResult(html: emitter.output, toc: emitter.toc)
    }

    func html(from source: String) -> String { render(source).html }
}

private struct HTMLEmitter: MarkupWalker {
    var output: String = ""
    var toc: [TOCEntry] = []
    private var usedSlugs: [String: Int] = [:]

    mutating func defaultVisit(_ markup: Markup) {
        for child in markup.children { visit(child) }
    }

    // MARK: - Blocks

    mutating func visitDocument(_ doc: Document) {
        for child in doc.children { visit(child) }
    }

    mutating func visitHeading(_ h: Heading) {
        let text = h.plainText
        let slug = makeSlug(text)
        toc.append(TOCEntry(id: slug, level: h.level, text: text))
        output += "<h\(h.level) id=\"\(Self.escape(slug))\">"
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

    mutating func makeSlug(_ text: String) -> String {
        let base = Self.slugify(text)
        let count = usedSlugs[base, default: 0]
        usedSlugs[base] = count + 1
        return count == 0 ? base : "\(base)-\(count)"
    }

    private static func slugify(_ text: String) -> String {
        let lower = text.lowercased()
        var out = ""
        var lastDash = false
        for scalar in lower.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                out.append(Character(scalar))
                lastDash = false
            } else if !lastDash && !out.isEmpty {
                out.append("-")
                lastDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "section" : out
    }

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
