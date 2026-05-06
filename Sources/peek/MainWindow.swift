import SwiftUI
import WebKit
import AppKit

struct MainWindow: View {
    @StateObject private var document = MarkdownDocument()
    @StateObject private var folder = FolderBrowser()
    @StateObject private var fileIndex = FileIndex()
    @StateObject private var contentSearcher = ContentSearcher()
    @ObservedObject private var launchBuffer = LaunchURLBuffer.shared
    @Environment(\.colorScheme) private var systemScheme
    @State private var themeOverride: ColorScheme? = nil

    @State private var findVisible = false
    @State private var findQuery = ""
    @State private var findLastResult = true
    @State private var findRequest = FindRequest(query: "", backwards: false, nonce: 0)
    @State private var zoom: Double = Pref.zoom
    @State private var webView: WKWebView?
    @State private var tocVisible = false
    @State private var sidebarCollapsed: Bool = Pref.sidebarCollapsed
    @State private var sidebarWidth: Double = Pref.sidebarWidth

    @State private var paletteVisible = false
    @State private var paletteQuery = ""
    @State private var paletteMode: PaletteMode = .files

    @State private var defaultHandlerPromptVisible = false

    enum PaletteMode: Equatable {
        case files
        case content
    }

    var body: some View {
        HStack(spacing: 0) {
            if let root = folder.root, !sidebarCollapsed {
                FileTreeSidebar(
                    root: root,
                    showAllFiles: Binding(get: { folder.showAllFiles }, set: { folder.showAllFiles = $0 }),
                    currentURL: document.currentURL,
                    loadedChildren: folder.loadedChildren,
                    onSelect: { url in document.open(url: url) },
                    onExpandDirectory: { url in folder.loadChildren(at: url) }
                )
                .frame(width: sidebarWidth)
                .transition(.move(edge: .leading))
                ResizableDivider(width: $sidebarWidth)
            }
            if tocVisible {
                TOCSidebar(entries: document.toc) { entry in
                    scrollToAnchor(entry.id)
                }
                .transition(.move(edge: .leading))
                Divider()
            }
            content
        }
        .animation(.easeInOut(duration: 0.15), value: tocVisible)
        .animation(.easeInOut(duration: 0.15), value: folder.root)
        .animation(.easeInOut(duration: 0.15), value: sidebarCollapsed)
        .onChange(of: folder.root?.url) { _, newRoot in
            fileIndex.build(root: newRoot, showAllFiles: folder.showAllFiles)
        }
        .onChange(of: folder.showAllFiles) { _, showAll in
            fileIndex.build(root: folder.root?.url, showAllFiles: showAll)
        }
        .onChange(of: paletteQuery) { _, q in
            if paletteMode == .content {
                contentSearcher.search(query: q, in: fileIndex.files)
            }
        }
        .onChange(of: paletteVisible) { _, visible in
            if !visible { contentSearcher.clear() }
        }
        .onAppear {
            handleLaunchURL(launchBuffer.pendingURL)
            maybePromptForDefaultHandler()
        }
        .onChange(of: launchBuffer.pendingURL) { _, new in handleLaunchURL(new) }
        .alert(
            "Open Markdown files with peek?",
            isPresented: $defaultHandlerPromptVisible
        ) {
            Button("Set as Default") {
                DefaultHandler.setPeekAsDefault()
                Pref.askedDefaultHandler = true
            }
            Button("Not Now", role: .cancel) {
                Pref.askedDefaultHandler = true
            }
        } message: {
            Text("Make peek the default app for .md files? You can change this anytime from the File menu, or in Finder via Get Info → Open with.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .peekSetAsDefault)) { _ in
            DefaultHandler.setPeekAsDefault()
        }
    }

    /// Show the default-handler prompt at most once. Skipped if peek is
    /// already the default, or if the user has already answered.
    private func maybePromptForDefaultHandler() {
        guard !Pref.askedDefaultHandler else { return }
        guard !DefaultHandler.isPeekDefault() else {
            // Mark asked so we don't re-evaluate on every launch — peek is
            // already the default, no question needed.
            Pref.askedDefaultHandler = true
            return
        }
        // Defer slightly so the alert lands after the window is on screen,
        // not during initial layout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            defaultHandlerPromptVisible = true
        }
    }

    /// Open whatever URL the launch buffer holds (cold-start argv,
    /// `application:openFile:`, or warm-start re-invocations) and clear the
    /// buffer so we don't re-act on the same URL.
    private func handleLaunchURL(_ url: URL?) {
        guard let url else { return }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        RecentFilesStore.shared.add(url)
        if isDir.boolValue {
            folder.open(rootURL: url)
        } else {
            document.open(url: url)
        }
        launchBuffer.pendingURL = nil
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let root = folder.root, let current = document.currentURL {
                let segs = BreadcrumbPath.segments(root: root.url, current: current)
                if !segs.isEmpty {
                    Breadcrumb(segments: segs) { seg in
                        if !seg.isFile {
                            NotificationCenter.default.post(name: .peekRevealInSidebar, object: seg.url)
                        }
                    }
                    Divider()
                }
            }
            contentBody
        }
    }

    private var contentBody: some View {
        ZStack(alignment: .top) {
            MarkdownWebView(
                html: document.html,
                theme: effectiveTheme,
                findRequest: findRequest,
                zoom: zoom,
                baseURL: document.currentURL?.deletingLastPathComponent(),
                fileURL: document.currentURL,
                onFindResult: { ok in findLastResult = ok },
                onWebViewReady: { view in webView = view },
                onInternalLink: { url in document.open(url: url) }
            )
            .ignoresSafeArea()

            if findVisible {
                FindBar(
                    query: $findQuery,
                    visible: $findVisible,
                    lastResultFound: findLastResult,
                    onNext: { issueFind(backwards: false) },
                    onPrev: { issueFind(backwards: true) }
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if paletteVisible {
                CommandPalette(
                    visible: $paletteVisible,
                    query: $paletteQuery,
                    items: paletteItems,
                    placeholder: palettePlaceholder,
                    emptyMessage: paletteEmptyMessage,
                    modeLabel: paletteModeLabel,
                    onActivate: handlePaletteActivation,
                    onModeToggle: togglePaletteMode
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.12), value: findVisible)
        .animation(.easeInOut(duration: 0.12), value: paletteVisible)
        .navigationTitle(document.displayTitle)
        .onChange(of: findQuery) { _, q in
            if !q.isEmpty { issueFind(backwards: false) }
        }
        .onChange(of: findVisible) { _, v in
            if !v { findQuery = ""; findLastResult = true }
        }
        .modifier(NotificationBridge(
            onOpenFile: { document.open(url: $0) },
            onOpenFolder: { folder.open(rootURL: $0) },
            onCloseFolder: { folder.close() },
            onRefreshFolder: { folder.refresh() },
            onReload: { document.reload() },
            onToggleTheme: { themeOverride = (effectiveTheme == .dark) ? .light : .dark },
            onFindOpen: { findVisible = true },
            onPaletteOpen: { openPalette(mode: .files) },
            onContentSearchOpen: { openPalette(mode: .content) },
            onZoomIn: { setZoom(zoom + Pref.zoomStep) },
            onZoomOut: { setZoom(zoom - Pref.zoomStep) },
            onZoomReset: { setZoom(Pref.defaultZoom) },
            onPrint: {
                if let webView {
                    PrintExport.print(webView: webView, title: document.displayTitle)
                }
            },
            onExportPDF: {
                if let webView {
                    let stem = (document.currentURL?.deletingPathExtension().lastPathComponent) ?? "document"
                    PrintExport.exportPDF(webView: webView, suggestedName: "\(stem).pdf")
                }
            },
            onToggleTOC: { tocVisible.toggle() },
            onToggleSidebar: {
                sidebarCollapsed.toggle()
                Pref.sidebarCollapsed = sidebarCollapsed
            }
        ))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    RecentFilesStore.shared.add(url)
                    if isDir.boolValue {
                        folder.open(rootURL: url)
                    } else {
                        document.open(url: url)
                    }
                }
            }
            return true
        }
    }

    private var effectiveTheme: ColorScheme {
        themeOverride ?? systemScheme
    }

    private func scrollToAnchor(_ id: String) {
        let escaped = id.replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function(){
          var el = document.getElementById('\(escaped)');
          if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func setZoom(_ value: Double) {
        let clamped = min(max(value, Pref.zoomMin), Pref.zoomMax)
        zoom = clamped
        Pref.zoom = clamped
    }

    private func issueFind(backwards: Bool) {
        findRequest = FindRequest(
            query: findQuery,
            backwards: backwards,
            nonce: findRequest.nonce &+ 1
        )
    }

    // MARK: - Palette

    private var paletteItems: [PaletteItem] {
        switch paletteMode {
        case .files: return fuzzyFileItems
        case .content: return contentMatchItems
        }
    }

    /// Top-N fuzzy matches for the current query, scored against the relative
    /// path of each indexed file.
    private var fuzzyFileItems: [PaletteItem] {
        guard let rootURL = folder.root?.url, !paletteQuery.isEmpty else { return [] }
        let q = paletteQuery
        let rootPath = rootURL.standardizedFileURL.path

        var scored: [(score: Double, url: URL)] = []
        scored.reserveCapacity(min(fileIndex.files.count, 1024))

        for url in fileIndex.files {
            let rel = relativePath(of: url, under: rootPath)
            guard let s = FuzzyMatch.score(query: q, in: rel) else { continue }
            scored.append((s, url))
        }
        scored.sort { $0.score > $1.score }

        return scored.prefix(50).map { entry in
            let rel = relativePath(of: entry.url, under: rootPath)
            let dir = (rel as NSString).deletingLastPathComponent
            return PaletteItem(
                id: entry.url.path,
                title: entry.url.lastPathComponent,
                subtitle: dir.isEmpty ? nil : dir
            )
        }
    }

    private var contentMatchItems: [PaletteItem] {
        guard let rootURL = folder.root?.url else { return [] }
        let rootPath = rootURL.standardizedFileURL.path
        return contentSearcher.matches.map { match in
            let rel = relativePath(of: match.url, under: rootPath)
            return PaletteItem(
                id: "\(match.url.path):\(match.lineNumber)",
                title: match.line.trimmingCharacters(in: .whitespaces),
                subtitle: "\(rel):\(match.lineNumber)",
                systemImage: "text.magnifyingglass"
            )
        }
    }

    private var paletteIsOpen: Bool { folder.root != nil }

    private var palettePlaceholder: String {
        switch paletteMode {
        case .files: return paletteIsOpen ? "Search files in this folder…" : "Open a folder to search files"
        case .content: return paletteIsOpen ? "Search file contents…" : "Open a folder to search contents"
        }
    }

    private var paletteEmptyMessage: String? {
        if !paletteIsOpen { return "Open a folder first (⌘⌥O) to search." }
        switch paletteMode {
        case .files:
            if fileIndex.isBuilding && paletteQuery.isEmpty { return "Indexing files…" }
            if paletteQuery.isEmpty { return "Type to search \(fileIndex.files.count) files in this folder…" }
            return "No matches for \"\(paletteQuery)\""
        case .content:
            if paletteQuery.isEmpty { return "Type to search across file contents…" }
            if contentSearcher.isSearching { return "Searching…" }
            return "No matches for \"\(paletteQuery)\""
        }
    }

    private func handlePaletteActivation(_ item: PaletteItem) {
        // File mode: id is the absolute file path.
        // Content mode: id is "path:lineNumber". Strip the line for now —
        // jumping to a specific line in the rendered HTML is a separate
        // problem (source-line → DOM offset mapping).
        let path: String
        if let colonIdx = item.id.lastIndex(of: ":"),
           paletteMode == .content,
           Int(item.id[item.id.index(after: colonIdx)...]) != nil {
            path = String(item.id[..<colonIdx])
        } else {
            path = item.id
        }
        document.open(url: URL(fileURLWithPath: path))
    }

    private func openPalette(mode: PaletteMode) {
        paletteMode = mode
        paletteQuery = ""
        paletteVisible = true
        if mode == .content { contentSearcher.clear() }
    }

    private var paletteModeLabel: String {
        switch paletteMode {
        case .files: return "Files"
        case .content: return "Content"
        }
    }

    /// Toggle between file and content modes. Wipes the query because the
    /// mode change shifts what the query *means* — file fuzzy match vs.
    /// content substring scan — and stale text would just produce confusing
    /// results.
    private func togglePaletteMode() {
        paletteMode = (paletteMode == .files) ? .content : .files
        paletteQuery = ""
        contentSearcher.clear()
    }

    private func relativePath(of url: URL, under rootPath: String) -> String {
        let p = url.standardizedFileURL.path
        if p.hasPrefix(rootPath + "/") {
            return String(p.dropFirst(rootPath.count + 1))
        }
        return p
    }
}

private struct NotificationBridge: ViewModifier {
    let onOpenFile: (URL) -> Void
    let onOpenFolder: (URL) -> Void
    let onCloseFolder: () -> Void
    let onRefreshFolder: () -> Void
    let onReload: () -> Void
    let onToggleTheme: () -> Void
    let onFindOpen: () -> Void
    let onPaletteOpen: () -> Void
    let onContentSearchOpen: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void
    let onPrint: () -> Void
    let onExportPDF: () -> Void
    let onToggleTOC: () -> Void
    let onToggleSidebar: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .peekOpenFile)) { note in
                if let url = note.object as? URL { onOpenFile(url) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .peekOpenFolder)) { note in
                if let url = note.object as? URL { onOpenFolder(url) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .peekCloseFolder)) { _ in onCloseFolder() }
            .onReceive(NotificationCenter.default.publisher(for: .peekRefreshFolder)) { _ in onRefreshFolder() }
            .onReceive(NotificationCenter.default.publisher(for: .peekReload)) { _ in onReload() }
            .onReceive(NotificationCenter.default.publisher(for: .peekToggleTheme)) { _ in onToggleTheme() }
            .onReceive(NotificationCenter.default.publisher(for: .peekFindOpen)) { _ in onFindOpen() }
            .onReceive(NotificationCenter.default.publisher(for: .peekPaletteOpen)) { _ in onPaletteOpen() }
            .onReceive(NotificationCenter.default.publisher(for: .peekContentSearchOpen)) { _ in onContentSearchOpen() }
            .onReceive(NotificationCenter.default.publisher(for: .peekZoomIn)) { _ in onZoomIn() }
            .onReceive(NotificationCenter.default.publisher(for: .peekZoomOut)) { _ in onZoomOut() }
            .onReceive(NotificationCenter.default.publisher(for: .peekZoomReset)) { _ in onZoomReset() }
            .onReceive(NotificationCenter.default.publisher(for: .peekPrint)) { _ in onPrint() }
            .onReceive(NotificationCenter.default.publisher(for: .peekExportPDF)) { _ in onExportPDF() }
            .onReceive(NotificationCenter.default.publisher(for: .peekToggleTOC)) { _ in onToggleTOC() }
            .onReceive(NotificationCenter.default.publisher(for: .peekToggleSidebar)) { _ in onToggleSidebar() }
    }
}

/// Draggable splitter between the file-tree sidebar and the document. Exposes
/// a 6pt-wide hit area with a 1pt visual divider; persists the new width on
/// drag-end so it survives window/app restarts.
private struct ResizableDivider: View {
    @Binding var width: Double
    @State private var dragStartWidth: Double?

    var body: some View {
        ZStack {
            Color.clear
            Divider()
        }
        .frame(width: 6)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active: NSCursor.resizeLeftRight.set()
            case .ended:  NSCursor.arrow.set()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartWidth == nil { dragStartWidth = width }
                    let proposed = (dragStartWidth ?? width) + value.translation.width
                    width = max(Pref.sidebarMinWidth, min(Pref.sidebarMaxWidth, proposed))
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    Pref.sidebarWidth = width
                }
        )
    }
}

struct FindRequest: Equatable {
    var query: String
    var backwards: Bool
    var nonce: UInt64
}
