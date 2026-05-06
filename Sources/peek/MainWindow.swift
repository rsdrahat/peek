import SwiftUI
import WebKit
import AppKit

struct MainWindow: View {
    @StateObject private var document = MarkdownDocument()
    @StateObject private var folder = FolderBrowser()
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
        .onAppear { handleLaunchURL(launchBuffer.pendingURL) }
        .onChange(of: launchBuffer.pendingURL) { _, new in handleLaunchURL(new) }
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
        }
        .animation(.easeInOut(duration: 0.12), value: findVisible)
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
}

private struct NotificationBridge: ViewModifier {
    let onOpenFile: (URL) -> Void
    let onOpenFolder: (URL) -> Void
    let onCloseFolder: () -> Void
    let onRefreshFolder: () -> Void
    let onReload: () -> Void
    let onToggleTheme: () -> Void
    let onFindOpen: () -> Void
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
