import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let theme: ColorScheme
    var findRequest: FindRequest = FindRequest(query: "", backwards: false, nonce: 0)
    var zoom: Double = 1.0
    var onFindResult: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let coord = context.coordinator
        let bodyChanged = coord.lastBody != html
        let themeChanged = coord.lastTheme != theme

        if coord.lastZoom != zoom {
            view.pageZoom = CGFloat(zoom)
            coord.lastZoom = zoom
        }

        if bodyChanged || coord.lastBody == nil {
            view.loadHTMLString(Self.shell(body: html, theme: theme),
                                baseURL: Bundle.module.resourceURL)
        } else if themeChanged {
            let isDark = theme == .dark
            let js = """
            document.documentElement.dataset.theme = '\(isDark ? "dark" : "light")';
            document.getElementById('hljs-light').disabled = \(isDark);
            document.getElementById('hljs-dark').disabled = \(!isDark);
            """
            view.evaluateJavaScript(js, completionHandler: nil)
        }

        // Find requests are deduped by nonce so parent re-renders don't re-search.
        if coord.lastFindNonce != findRequest.nonce {
            coord.lastFindNonce = findRequest.nonce
            runFind(on: view, request: findRequest)
        }

        coord.lastBody = html
        coord.lastTheme = theme
    }

    private func runFind(on view: WKWebView, request: FindRequest) {
        guard !request.query.isEmpty else { return }
        let config = WKFindConfiguration()
        config.backwards = request.backwards
        config.caseSensitive = false
        config.wraps = true
        view.find(request.query, configuration: config) { result in
            onFindResult(result.matchFound)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var lastBody: String?
        var lastTheme: ColorScheme?
        var lastFindNonce: UInt64 = 0
        var lastZoom: Double = -1

        func webView(_ webView: WKWebView,
                     decidePolicyFor nav: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = nav.request.url, nav.navigationType == .linkActivated else {
                decisionHandler(.allow); return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    static func shell(body: String, theme: ColorScheme) -> String {
        let themeAttr = theme == .dark ? "dark" : "light"
        let base = loadResource("base.css")
        let hljsLight = loadResource("hljs-light.css")
        let hljsDark = loadResource("hljs-dark.css")
        let hljs = loadResource("highlight.min.js")
        return """
        <!doctype html>
        <html data-theme="\(themeAttr)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>\(base)</style>
        <style id="hljs-light"\(theme == .dark ? " disabled" : "")>\(hljsLight)</style>
        <style id="hljs-dark"\(theme == .dark ? "" : " disabled")>\(hljsDark)</style>
        </head>
        <body><main class="page">\(body)</main>
        <script>\(hljs)</script>
        <script>hljs.highlightAll();</script>
        </body>
        </html>
        """
    }

    private static func loadResource(_ name: String) -> String {
        let url = Bundle.module.url(forResource: "Resources/\(name)", withExtension: nil)
        return (url.flatMap { try? String(contentsOf: $0) }) ?? ""
    }
}
