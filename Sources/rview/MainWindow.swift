import SwiftUI
import WebKit

struct MainWindow: View {
    @StateObject private var document = MarkdownDocument()
    @Environment(\.colorScheme) private var systemScheme
    @State private var themeOverride: ColorScheme? = nil

    @State private var findVisible = false
    @State private var findQuery = ""
    @State private var findLastResult = true
    @State private var findRequest = FindRequest(query: "", backwards: false, nonce: 0)
    @State private var zoom: Double = Pref.zoom
    @State private var webView: WKWebView?

    var body: some View {
        ZStack(alignment: .top) {
            MarkdownWebView(
                html: document.html,
                theme: effectiveTheme,
                findRequest: findRequest,
                zoom: zoom,
                baseURL: document.currentURL?.deletingLastPathComponent(),
                fileURL: document.currentURL,
                onFindResult: { ok in findLastResult = ok },
                onWebViewReady: { view in webView = view }
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
        .onReceive(NotificationCenter.default.publisher(for: .rviewOpenFile)) { note in
            if let url = note.object as? URL { document.open(url: url) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rviewReload)) { _ in
            document.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .rviewToggleTheme)) { _ in
            themeOverride = (effectiveTheme == .dark) ? .light : .dark
        }
        .onReceive(NotificationCenter.default.publisher(for: .rviewFindOpen)) { _ in
            findVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .rviewZoomIn)) { _ in
            setZoom(zoom + Pref.zoomStep)
        }
        .onReceive(NotificationCenter.default.publisher(for: .rviewZoomOut)) { _ in
            setZoom(zoom - Pref.zoomStep)
        }
        .onReceive(NotificationCenter.default.publisher(for: .rviewZoomReset)) { _ in
            setZoom(Pref.defaultZoom)
        }
        .onReceive(NotificationCenter.default.publisher(for: .rviewPrint)) { _ in
            if let webView {
                PrintExport.print(webView: webView, title: document.displayTitle)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rviewExportPDF)) { _ in
            if let webView {
                let stem = (document.currentURL?.deletingPathExtension().lastPathComponent) ?? "document"
                PrintExport.exportPDF(webView: webView, suggestedName: "\(stem).pdf")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { DispatchQueue.main.async { document.open(url: url) } }
            }
            return true
        }
    }

    private var effectiveTheme: ColorScheme {
        themeOverride ?? systemScheme
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

struct FindRequest: Equatable {
    var query: String
    var backwards: Bool
    var nonce: UInt64
}
