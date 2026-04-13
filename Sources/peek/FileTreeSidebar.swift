import SwiftUI

struct FileTreeSidebar: View {
    let root: FolderNode
    @Binding var showAllFiles: Bool
    let currentURL: URL?
    let onSelect: (URL) -> Void

    @State private var expanded: Set<URL> = []
    @State private var selection: URL?
    @State private var pendingG: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let rows = FlatRow.flatten(children: root.children ?? [], expanded: expanded)
                        ForEach(rows, id: \.node.id) { row in
                            NodeRow(
                                node: row.node,
                                depth: row.depth,
                                isOpen: currentURL == row.node.url,
                                isSelected: selection == row.node.url,
                                isExpanded: expanded.contains(row.node.url),
                                onTap: { activate(row.node) }
                            )
                            .id(row.node.url)
                        }
                        if (root.children ?? []).isEmpty {
                            Text(showAllFiles ? "Empty folder" : "No markdown files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 16)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: selection) { _, new in
                    if let new { withAnimation(.easeOut(duration: 0.08)) { proxy.scrollTo(new, anchor: .center) } }
                }
            }
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)
        .background(.thinMaterial)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear {
            if selection == nil { selection = firstFile() ?? firstNode() }
            focused = true
        }
        .onKeyPress(keys: ["j", "k", "h", "l", "g", "G", " ", "o"]) { press in
            handle(key: press.key); return .handled
        }
        .onKeyPress(.return) { activateSelection(); return .handled }
        .onKeyPress(.downArrow) { move(+1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
    }

    private var header: some View {
        HStack {
            Text(root.url.lastPathComponent)
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Toggle(isOn: $showAllFiles) {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .help(showAllFiles ? "Showing all files — click to show markdown only" : "Showing markdown only — click to show all files")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Keyboard

    private func handle(key: KeyEquivalent) {
        let wasPendingG = pendingG
        pendingG = false
        switch key {
        case "j": move(+1)
        case "k": move(-1)
        case "h": collapseOrParent()
        case "l": expandOrEnter()
        case "g":
            if wasPendingG { gotoFirst() }
            else { pendingG = true; schedulePendingGReset() }
        case "G": gotoLast()
        case " ", "o": activateSelection()
        default: break
        }
    }

    private func schedulePendingGReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pendingG = false }
    }

    private func move(_ delta: Int) {
        let rows = visibleRows()
        guard !rows.isEmpty else { return }
        let i = rows.firstIndex(where: { $0.node.url == selection }) ?? -1
        let next = max(0, min(rows.count - 1, i + delta))
        if next < 0 { return }
        selection = rows[next].node.url
    }

    private func gotoFirst() {
        selection = visibleRows().first?.node.url
    }

    private func gotoLast() {
        selection = visibleRows().last?.node.url
    }

    private func expandOrEnter() {
        guard let sel = selection, let node = findNode(sel) else { return }
        if node.isDirectory {
            if !expanded.contains(sel) {
                expanded.insert(sel)
            } else if let first = node.children?.first {
                selection = first.url
            }
        }
    }

    private func collapseOrParent() {
        guard let sel = selection, let node = findNode(sel) else { return }
        if node.isDirectory, expanded.contains(sel) {
            expanded.remove(sel)
        } else if let parent = findParent(of: sel) {
            selection = parent.url
        }
    }

    private func activateSelection() {
        guard let sel = selection, let node = findNode(sel) else { return }
        activate(node)
    }

    private func activate(_ node: FolderNode) {
        selection = node.url
        if node.isDirectory {
            if expanded.contains(node.url) { expanded.remove(node.url) }
            else { expanded.insert(node.url) }
        } else {
            onSelect(node.url)
        }
    }

    // MARK: - Tree queries

    private func visibleRows() -> [FlatRow] {
        FlatRow.flatten(children: root.children ?? [], expanded: expanded)
    }

    private func firstNode() -> URL? {
        root.children?.first?.url
    }

    private func firstFile() -> URL? {
        for row in visibleRows() where !row.node.isDirectory {
            return row.node.url
        }
        return nil
    }

    private func findNode(_ url: URL) -> FolderNode? {
        FolderNode.find(url: url, in: root.children ?? [])
    }

    private func findParent(of url: URL) -> FolderNode? {
        FolderNode.findParent(of: url, in: root.children ?? [], parent: nil)
    }
}

// MARK: - Flat visible row

struct FlatRow {
    let node: FolderNode
    let depth: Int

    static func flatten(children: [FolderNode], expanded: Set<URL>, depth: Int = 0) -> [FlatRow] {
        var out: [FlatRow] = []
        for node in children {
            out.append(FlatRow(node: node, depth: depth))
            if node.isDirectory, expanded.contains(node.url), let kids = node.children {
                out.append(contentsOf: flatten(children: kids, expanded: expanded, depth: depth + 1))
            }
        }
        return out
    }
}

extension FolderNode {
    static func find(url: URL, in nodes: [FolderNode]) -> FolderNode? {
        for n in nodes {
            if n.url == url { return n }
            if let kids = n.children, let hit = find(url: url, in: kids) { return hit }
        }
        return nil
    }

    static func findParent(of url: URL, in nodes: [FolderNode], parent: FolderNode?) -> FolderNode? {
        for n in nodes {
            if n.url == url { return parent }
            if let kids = n.children, let hit = findParent(of: url, in: kids, parent: n) { return hit }
        }
        return nil
    }
}

// MARK: - Row view

private struct NodeRow: View {
    let node: FolderNode
    let depth: Int
    let isOpen: Bool
    let isSelected: Bool
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if node.isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .frame(width: 10)
                        .foregroundStyle(.secondary)
                } else {
                    Spacer().frame(width: 10)
                }
                Image(systemName: node.isDirectory ? "folder" : "doc.text")
                    .font(.caption)
                    .foregroundStyle(node.isDirectory ? .secondary : .primary)
                Text(node.name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(12 + depth * 14))
            .padding(.trailing, 12)
            .padding(.vertical, 3)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.28) }
        if isOpen { return Color.accentColor.opacity(0.14) }
        return .clear
    }
}
