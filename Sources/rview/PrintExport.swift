import AppKit
import WebKit
import UniformTypeIdentifiers

enum PrintExport {
    static func print(webView: WKWebView, title: String) {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.horizontalPagination = .automatic
        info.verticalPagination = .automatic
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 36
        info.rightMargin = 36
        let op = webView.printOperation(with: info)
        op.jobTitle = title
        op.view?.frame = NSRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        if let window = webView.window {
            op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            _ = op.run()
        }
    }

    static func exportPDF(webView: WKWebView, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                do {
                    try data.write(to: url)
                } catch {
                    Swift.print("PDF write failed: \(error)")
                }
            case .failure(let error):
                Swift.print("PDF generation failed: \(error)")
            }
        }
    }
}
