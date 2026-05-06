import Foundation
import Combine

@MainActor
final class FolderBrowser: ObservableObject {
    @Published private(set) var root: FolderNode?
    @Published var showAllFiles: Bool = false {
        didSet { rebuild() }
    }

    private var rootURL: URL?
    private var watcher: FolderWatcher?

    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    func open(rootURL url: URL) {
        self.rootURL = url
        rebuild()
        watcher = FolderWatcher(url: url) { [weak self] in
            self?.rebuild()
        }
    }

    func close() {
        rootURL = nil
        root = nil
        watcher = nil
    }

    /// Force a tree rebuild from disk. FSEvents covers the common case;
    /// this exists as a manual fallback (network mounts, missed events).
    func refresh() {
        rebuild()
    }

    var isOpen: Bool { rootURL != nil }

    private func rebuild() {
        guard let url = rootURL else { root = nil; return }
        root = Self.buildNode(at: url, showAllFiles: showAllFiles)
    }

    static func buildNode(at url: URL, showAllFiles: Bool) -> FolderNode {
        let children = listChildren(of: url, showAllFiles: showAllFiles)
        return FolderNode(url: url, isDirectory: true, children: children)
    }

    static func listChildren(of url: URL, showAllFiles: Bool) -> [FolderNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsSubdirectoryDescendants]
        ) else { return [] }

        var nodes: [FolderNode] = []
        for entry in entries {
            let name = entry.lastPathComponent
            if name.hasPrefix(".") { continue }

            var isDir: ObjCBool = false
            fm.fileExists(atPath: entry.path, isDirectory: &isDir)

            if isDir.boolValue {
                let grand = listChildren(of: entry, showAllFiles: showAllFiles)
                // Hide empty directories that have no markdown descendants in md-only mode.
                if !showAllFiles && grand.isEmpty { continue }
                nodes.append(FolderNode(url: entry, isDirectory: true, children: grand))
            } else {
                let ext = entry.pathExtension.lowercased()
                if !showAllFiles && !markdownExtensions.contains(ext) { continue }
                nodes.append(FolderNode(url: entry, isDirectory: false, children: nil))
            }
        }

        // Folders first, then files, both alphabetical (case-insensitive).
        nodes.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            return a.url.lastPathComponent.localizedCaseInsensitiveCompare(b.url.lastPathComponent) == .orderedAscending
        }
        return nodes
    }
}

struct FolderNode: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let children: [FolderNode]?

    var id: URL { url }
    var name: String { url.lastPathComponent }

    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.url == rhs.url && lhs.isDirectory == rhs.isDirectory && lhs.children == rhs.children
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(isDirectory)
    }
}
