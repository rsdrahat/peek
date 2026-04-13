import SwiftUI

struct FileTreeSidebar: View {
    let root: FolderNode
    @Binding var showAllFiles: Bool
    let currentURL: URL?
    let onSelect: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(root.children ?? []) { node in
                        NodeRow(node: node, depth: 0, currentURL: currentURL, onSelect: onSelect)
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
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)
        .background(.thinMaterial)
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
}

private struct NodeRow: View {
    let node: FolderNode
    let depth: Int
    let currentURL: URL?
    let onSelect: (URL) -> Void

    @State private var expanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: activate) {
                HStack(spacing: 4) {
                    if node.isDirectory {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
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
                .background(isCurrent ? Color.accentColor.opacity(0.18) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if node.isDirectory && expanded, let kids = node.children {
                ForEach(kids) { child in
                    NodeRow(node: child, depth: depth + 1, currentURL: currentURL, onSelect: onSelect)
                }
            }
        }
    }

    private var isCurrent: Bool {
        !node.isDirectory && currentURL == node.url
    }

    private func activate() {
        if node.isDirectory {
            expanded.toggle()
        } else {
            onSelect(node.url)
        }
    }
}
