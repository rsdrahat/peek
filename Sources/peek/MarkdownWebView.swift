import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let theme: ColorScheme
    var findRequest: FindRequest = FindRequest(query: "", backwards: false, nonce: 0)
    var zoom: Double = 1.0
    var baseURL: URL? = nil
    var fileURL: URL? = nil
    var onFindResult: (Bool) -> Void = { _ in }
    var onWebViewReady: (WKWebView) -> Void = { _ in }
    var onInternalLink: (URL) -> Void = { _ in }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "peekScroll")
        config.userContentController = userContent

        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        context.coordinator.onInternalLink = onInternalLink
        onWebViewReady(view)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let coord = context.coordinator
        coord.onInternalLink = onInternalLink
        let bodyChanged = coord.lastBody != html
        let themeChanged = coord.lastTheme != theme
        let baseChanged = coord.lastBaseURL != baseURL
        let fileChanged = coord.lastFileURL != fileURL

        if coord.lastZoom != zoom {
            view.pageZoom = CGFloat(zoom)
            coord.lastZoom = zoom
        }

        if bodyChanged || baseChanged || fileChanged || coord.lastBody == nil {
            coord.pendingFileURL = fileURL
            let effectiveBase = baseURL ?? Bundle.module.resourceURL
            view.loadHTMLString(Self.shell(body: html, theme: theme),
                                baseURL: effectiveBase)
            coord.lastBaseURL = baseURL
            coord.lastFileURL = fileURL
        } else if themeChanged {
            let isDark = theme == .dark
            let js = """
            document.documentElement.dataset.theme = '\(isDark ? "dark" : "light")';
            document.getElementById('hljs-light').disabled = \(isDark);
            document.getElementById('hljs-dark').disabled = \(!isDark);
            """
            view.evaluateJavaScript(js, completionHandler: nil)
        }

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

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var lastBody: String?
        var lastTheme: ColorScheme?
        var lastFindNonce: UInt64 = 0
        var lastZoom: Double = -1
        var lastBaseURL: URL?
        var lastFileURL: URL?
        var pendingFileURL: URL?
        var onInternalLink: (URL) -> Void = { _ in }

        func webView(_ webView: WKWebView,
                     decidePolicyFor nav: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = nav.request.url, nav.navigationType == .linkActivated else {
                decisionHandler(.allow); return
            }
            if MarkdownWebView.isInternalMarkdownLink(url) {
                onInternalLink(url.standardizedFileURL)
                decisionHandler(.cancel)
                return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = pendingFileURL else { return }
            Task { @MainActor in
                let y = await ScrollStore.shared.scrollY(for: url)
                if y > 0 {
                    webView.evaluateJavaScript("window.scrollTo(0, \(y));", completionHandler: nil)
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "peekScroll",
                  let y = (message.body as? NSNumber)?.doubleValue,
                  let url = lastFileURL else { return }
            Task { await ScrollStore.shared.setScrollY(y, for: url) }
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
        <script>
        hljs.highlightAll();
        (function(){
          let t = null;
          window.addEventListener('scroll', function() {
            if (t) clearTimeout(t);
            t = setTimeout(function() {
              window.webkit.messageHandlers.peekScroll.postMessage(window.scrollY);
            }, 120);
          }, { passive: true });
        })();
        </script>
        </body>
        </html>
        """
    }

    static func isInternalMarkdownLink(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown" || ext == "mdown"
    }

    private static func loadResource(_ name: String) -> String {
        let url = Bundle.module.url(forResource: "Resources/\(name)", withExtension: nil)
        return (url.flatMap { try? String(contentsOf: $0) }) ?? ""
    }
}
