import SwiftUI

struct FileTreeSidebar: View {
    let root: FolderNode
    @Binding var showAllFiles: Bool
    let currentURL: URL?
    let loadedChildren: [URL: [FolderNode]]
    let onSelect: (URL) -> Void
    let onExpandDirectory: (URL) -> Void

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
                        let rows = FlatRow.flatten(
                            children: root.children ?? [],
                            expanded: expanded,
                            loadedChildren: loadedChildren
                        )
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
        // Width is driven by the parent (MainWindow) via .frame(width:) so the
        // user-resizable splitter can take control. Keep an absolute min so
        // header + chevron column never collide.
        .frame(minWidth: 120, maxWidth: .infinity)
        .background(.thinMaterial)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear {
            if selection == nil { selection = currentURL ?? firstFile() ?? firstNode() }
            if let current = currentURL { expandAncestors(of: current) }
            focused = true
        }
        .onChange(of: currentURL) { _, new in
            guard let new else { return }
            expandAncestors(of: new)
            selection = new
        }
        .onKeyPress(keys: ["j", "k", "h", "l", "g", "G", " ", "o"]) { press in
            handle(key: press.key); return .handled
        }
        .onKeyPress(.return) { activateSelection(); return .handled }
        .onKeyPress(.downArrow) { move(+1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onReceive(NotificationCenter.default.publisher(for: .peekRevealInSidebar)) { note in
            if let url = note.object as? URL { reveal(url: url) }
        }
    }

    private func reveal(url: URL) {
        let standardized = url.standardizedFileURL
        let rootStd = root.url.standardizedFileURL
        // Walk up from the target's parent directory, expanding every
        // ancestor that lies under root.
        let fm = FileManager.default
        var startDir = standardized
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: startDir.path, isDirectory: &isDir), !isDir.boolValue {
            startDir = startDir.deletingLastPathComponent()
        }
        var dir = startDir
        while dir.path.hasPrefix(rootStd.path + "/") {
            onExpandDirectory(dir)
            expanded.insert(dir)
            dir = dir.deletingLastPathComponent()
        }
        selection = standardized
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
                onExpandDirectory(sel)
                expanded.insert(sel)
            } else {
                let kids = node.children ?? loadedChildren[sel] ?? []
                if let first = kids.first { selection = first.url }
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
            if expanded.contains(node.url) {
                expanded.remove(node.url)
            } else {
                onExpandDirectory(node.url)
                expanded.insert(node.url)
            }
        } else {
            onSelect(node.url)
        }
    }

    // MARK: - Tree queries

    private func visibleRows() -> [FlatRow] {
        FlatRow.flatten(
            children: root.children ?? [],
            expanded: expanded,
            loadedChildren: loadedChildren
        )
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
        if root.url == url { return root }
        let parent = url.deletingLastPathComponent()
        let siblings: [FolderNode] = parent == root.url
            ? (root.children ?? [])
            : (loadedChildren[parent] ?? [])
        return siblings.first(where: { $0.url == url })
    }

    private func findParent(of url: URL) -> FolderNode? {
        findNode(url.deletingLastPathComponent())
    }

    private func expandAncestors(of url: URL) {
        let rootPath = root.url.standardizedFileURL.path
        var dir = url.standardizedFileURL.deletingLastPathComponent()
        while dir.path.hasPrefix(rootPath) && dir.path != rootPath {
            onExpandDirectory(dir)
            expanded.insert(dir)
            dir = dir.deletingLastPathComponent()
        }
    }
}

// MARK: - Flat visible row

struct FlatRow {
    let node: FolderNode
    let depth: Int

    static func flatten(
        children: [FolderNode],
        expanded: Set<URL>,
        loadedChildren: [URL: [FolderNode]] = [:],
        depth: Int = 0
    ) -> [FlatRow] {
        var out: [FlatRow] = []
        for node in children {
            out.append(FlatRow(node: node, depth: depth))
            guard node.isDirectory, expanded.contains(node.url) else { continue }
            // Root level keeps its inline children; deeper levels resolve via the cache.
            let kids = node.children ?? loadedChildren[node.url] ?? []
            out.append(contentsOf: flatten(
                children: kids,
                expanded: expanded,
                loadedChildren: loadedChildren,
                depth: depth + 1
            ))
        }
        return out
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
