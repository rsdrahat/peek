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
        didSet { rebuildSync() }
    }

    private var rootURL: URL?
    private var watcher: FolderWatcher?

    /// Serial queue for off-main directory walks triggered by FSEvents and
    /// manual refresh. Initial open and showAllFiles toggle stay sync — the
    /// user is waiting and one level is sub-millisecond anyway.
    private let rebuildQueue = DispatchQueue(label: "peek.folderbrowser.rebuild", qos: .userInitiated)

    nonisolated static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    /// Directories that are virtually never useful to browse. Skipped in
    /// markdown-only mode; revealed when "show all files" is on. Dot-dirs
    /// (`.git`, `.build`, `.next`, …) are already filtered separately, so
    /// only non-dot offenders need to be listed here.
    nonisolated static let ignoredDirNames: Set<String> = [
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
        rebuildSync()
        watcher = FolderWatcher(url: url) { [weak self] in
            self?.rebuildAsync()
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
        rebuildAsync()
    }

    /// Populate the children of `url` if not already loaded. Called by the
    /// sidebar when the user expands a directory below the root.
    func loadChildren(at url: URL) {
        guard loadedChildren[url] == nil else { return }
        loadedChildren[url] = Self.listChildren(of: url, showAllFiles: showAllFiles)
    }

    var isOpen: Bool { rootURL != nil }

    /// Synchronous rebuild — used for the initial open and the showAllFiles
    /// toggle, where the user is actively waiting and we want the next paint
    /// to reflect the new state.
    private func rebuildSync() {
        guard let url = rootURL else {
            root = nil
            loadedChildren = [:]
            return
        }
        let topLevel = Self.listChildren(of: url, showAllFiles: showAllFiles)
        root = FolderNode(url: url, isDirectory: true, children: topLevel)

        let fm = FileManager.default
        var refreshed: [URL: [FolderNode]] = [:]
        for cached in loadedChildren.keys {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: cached.path, isDirectory: &isDir), isDir.boolValue else { continue }
            refreshed[cached] = Self.listChildren(of: cached, showAllFiles: showAllFiles)
        }
        loadedChildren = refreshed
    }

    /// Off-main rebuild — used for FSEvents firings and manual refresh, where
    /// blocking the main thread would mean a stutter or beach-ball during
    /// scroll. Walks happen on a serial queue so a burst of FSEvents doesn't
    /// race; results that arrive after the user closed or toggled showAllFiles
    /// are discarded.
    private func rebuildAsync() {
        guard let url = rootURL else { return }
        let showAll = showAllFiles
        let cachedURLs = Array(loadedChildren.keys)

        rebuildQueue.async {
            let topLevel = Self.listChildren(of: url, showAllFiles: showAll)
            let refreshed = Self.refreshedChildren(forCached: cachedURLs, showAllFiles: showAll)
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Discard if state changed while we were off-main.
                guard self.rootURL == url, self.showAllFiles == showAll else { return }
                self.root = FolderNode(url: url, isDirectory: true, children: topLevel)
                self.loadedChildren = refreshed
            }
        }
    }

    /// Re-list each previously-loaded subtree. Returns immutably so the
    /// concurrently-executing closure that captures it doesn't trip the
    /// Swift 6 "captured var in concurrent context" rule.
    nonisolated static func refreshedChildren(
        forCached cached: [URL],
        showAllFiles: Bool
    ) -> [URL: [FolderNode]] {
        let fm = FileManager.default
        var out: [URL: [FolderNode]] = [:]
        for url in cached {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            out[url] = listChildren(of: url, showAllFiles: showAllFiles)
        }
        return out
    }

    /// One level of `url` — fast, no recursion. Filters dot-files, the
    /// `ignoredDirNames` set (in md-only mode), and non-markdown files
    /// (in md-only mode).
    nonisolated static func listChildren(of url: URL, showAllFiles: Bool) -> [FolderNode] {
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
