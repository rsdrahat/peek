import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let theme: ColorScheme

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

        if bodyChanged || coord.lastBody == nil {
            view.loadHTMLString(Self.shell(body: html, theme: theme),
                                baseURL: Bundle.module.resourceURL)
        } else if themeChanged {
            // Theme-only change: flip attribute + swap hljs stylesheet in-page, preserve scroll.
            let isDark = theme == .dark
            let js = """
            document.documentElement.dataset.theme = '\(isDark ? "dark" : "light")';
            document.getElementById('hljs-light').disabled = \(isDark);
            document.getElementById('hljs-dark').disabled = \(!isDark);
            """
            view.evaluateJavaScript(js, completionHandler: nil)
        }

        coord.lastBody = html
        coord.lastTheme = theme
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var lastBody: String?
        var lastTheme: ColorScheme?

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
