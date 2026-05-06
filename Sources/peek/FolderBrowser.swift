import Foundation
import Combine

@MainActor
final class FolderBrowser: ObservableObject {
    /// The root node, populated to one level deep. Subdirectories carry
    /// `children == nil` until the user expands them — at which point the
    /// sidebar calls `loadChildren(at:)` to populate `loadedChildren`.
    @Published private(set) var root: FolderNode?

    /// Cache of loaded subtrees, keyed by directory URL. The sidebar uses
    /// this to find children for expanded directories below the root.
    @Published private(set) var loadedChildren: [URL: [FolderNode]] = [:]

    @Published var showAllFiles: Bool = false {
        didSet { rebuild() }
    }

    private var rootURL: URL?
    private var watcher: FolderWatcher?

    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    /// Directories that are virtually never useful to browse. Skipped in
    /// markdown-only mode; revealed when "show all files" is on. Dot-dirs
    /// (`.git`, `.build`, `.next`, …) are already filtered separately, so
    /// only non-dot offenders need to be listed here.
    static let ignoredDirNames: Set<String> = [
        "node_modules",
        "__pycache__",
        "target",
        "dist",
        "build",
        "venv",
        "vendor",
        "out",
    ]

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
        loadedChildren = [:]
        watcher = nil
    }

    /// Force a tree rebuild from disk. FSEvents covers the common case;
    /// this exists as a manual fallback (network mounts, missed events).
    func refresh() {
        rebuild()
    }

    /// Populate the children of `url` if not already loaded. Called by the
    /// sidebar when the user expands a directory below the root.
    func loadChildren(at url: URL) {
        guard loadedChildren[url] == nil else { return }
        loadedChildren[url] = Self.listChildren(of: url, showAllFiles: showAllFiles)
    }

    var isOpen: Bool { rootURL != nil }

    private func rebuild() {
        guard let url = rootURL else {
            root = nil
            loadedChildren = [:]
            return
        }
        let topLevel = Self.listChildren(of: url, showAllFiles: showAllFiles)
        root = FolderNode(url: url, isDirectory: true, children: topLevel)

        // Refresh subtrees that were already loaded so they reflect current
        // disk state. Drop entries whose directory has disappeared.
        let fm = FileManager.default
        var refreshed: [URL: [FolderNode]] = [:]
        for cached in loadedChildren.keys {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: cached.path, isDirectory: &isDir), isDir.boolValue else { continue }
            refreshed[cached] = Self.listChildren(of: cached, showAllFiles: showAllFiles)
        }
        loadedChildren = refreshed
    }

    /// One level of `url` — fast, no recursion. Filters dot-files, the
    /// `ignoredDirNames` set (in md-only mode), and non-markdown files
    /// (in md-only mode).
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
                if !showAllFiles && ignoredDirNames.contains(name) { continue }
                // Lazy: don't recurse. Children resolve via loadedChildren on expand.
                nodes.append(FolderNode(url: entry, isDirectory: true, children: nil))
            } else {
                let ext = entry.pathExtension.lowercased()
                if !showAllFiles && !markdownExtensions.contains(ext) { continue }
                nodes.append(FolderNode(url: entry, isDirectory: false, children: nil))
            }
        }

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
