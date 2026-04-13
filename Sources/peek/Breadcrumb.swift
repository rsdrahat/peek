import SwiftUI

struct BreadcrumbSegment: Identifiable, Equatable {
    let url: URL
    let name: String
    let isFile: Bool
    var id: URL { url }
}

enum BreadcrumbPath {
    /// Compute clickable segments from `root` down to `current`. Returns an empty
    /// array if `current` is not inside `root` or equals `root` itself. The root
    /// itself is included as the first segment so users can jump back to the top.
    static func segments(root: URL, current: URL) -> [BreadcrumbSegment] {
        let r = root.standardizedFileURL
        let c = current.standardizedFileURL
        let rPath = r.path
        let cPath = c.path
        guard cPath.hasPrefix(rPath + "/") else { return [] }
        let tail = String(cPath.dropFirst(rPath.count + 1))
        let parts = tail.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { return [] }

        var segs: [BreadcrumbSegment] = [
            BreadcrumbSegment(url: r, name: r.lastPathComponent, isFile: false)
        ]
        var cursor = r
        for (i, part) in parts.enumerated() {
            cursor = cursor.appendingPathComponent(part)
            segs.append(BreadcrumbSegment(url: cursor, name: part, isFile: i == parts.count - 1))
        }
        return segs
    }
}

struct Breadcrumb: View {
    let segments: [BreadcrumbSegment]
    let onTap: (BreadcrumbSegment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { idx, seg in
                    if idx > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button(action: { onTap(seg) }) {
                        Text(seg.name)
                            .font(.caption)
                            .foregroundStyle(seg.isFile ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help(seg.url.path)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
}
