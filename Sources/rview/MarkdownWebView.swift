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
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let page = Self.shell(body: html, theme: theme)
        view.loadHTMLString(page, baseURL: Bundle.module.resourceURL)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
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
        let cssName = theme == .dark ? "dark.css" : "light.css"
        let hljsCSSName = theme == .dark ? "hljs-dark.css" : "hljs-light.css"
        let css = loadResource(cssName) + "\n" + loadResource(hljsCSSName)
        let hljs = loadResource("highlight.min.js")
        return """
        <!doctype html>
        <html data-theme="\(themeAttr)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>\(css)</style>
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
