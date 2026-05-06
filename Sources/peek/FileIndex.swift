import Foundation
import Combine

/// In-memory index of file URLs under the open folder, used by the command
/// palette's fuzzy file search. Built (recursively) on a background queue
/// when the folder opens or refreshes; queried synchronously on every
/// keystroke. No background watcher — the index is rebuilt on folder open
/// and on manual refresh; per CLAUDE.md, the v1 bar is "results visible
/// within a frame on a 10k-file folder" and a fresh walk is fast enough.
@MainActor
final class FileIndex: ObservableObject {
    @Published private(set) var files: [URL] = []
    @Published private(set) var isBuilding: Bool = false

    private let queue = DispatchQueue(label: "peek.fileindex", qos: .userInitiated)
    private var generation: Int = 0

    /// Mirrors the sidebar's noise list. When PR #72 lands, both consumers
    /// will share `FolderBrowser.ignoredDirNames`; for now this branch keeps
    /// a local copy so search isn't blocked on the perf stack.
    nonisolated static let ignoredDirNames: Set<String> = [
        "node_modules", "__pycache__", "target", "dist",
        "build", "venv", "vendor", "out",
    ]

    nonisolated static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    /// Walk `root` on a background queue and publish the result. Subsequent
    /// calls supersede earlier ones — only the most recent walk's result is
    /// applied (generation guard).
    func build(root: URL?, showAllFiles: Bool) {
        generation &+= 1
        let myGen = generation

        guard let root else {
            files = []
            isBuilding = false
            return
        }

        isBuilding = true
        queue.async {
            let result = Self.walk(root: root, showAllFiles: showAllFiles)
            Task { @MainActor [weak self] in
                guard let self, self.generation == myGen else { return }
                self.files = result
                self.isBuilding = false
            }
        }
    }

    func clear() {
        generation &+= 1
        files = []
        isBuilding = false
    }

    /// Recursive walk skipping dot-dirs and (in md-only mode) the
    /// `FolderBrowser.ignoredDirNames` set. Markdown-only mode also filters
    /// non-markdown files, matching the sidebar's behavior.
    nonisolated static func walk(root: URL, showAllFiles: Bool) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var out: [URL] = []
        out.reserveCapacity(1024)

        while let url = enumerator.nextObject() as? URL {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                let name = url.lastPathComponent
                if !showAllFiles && ignoredDirNames.contains(name) {
                    enumerator.skipDescendants()
                }
            } else {
                if !showAllFiles {
                    let ext = url.pathExtension.lowercased()
                    if !markdownExtensions.contains(ext) { continue }
                }
                out.append(url)
            }
        }
        return out
    }
}
