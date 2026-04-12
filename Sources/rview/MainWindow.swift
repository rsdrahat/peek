import SwiftUI

struct MainWindow: View {
    @StateObject private var document = MarkdownDocument()
    @Environment(\.colorScheme) private var systemScheme
    @State private var themeOverride: ColorScheme? = nil

    var body: some View {
        MarkdownWebView(html: document.html, theme: effectiveTheme)
            .ignoresSafeArea()
            .navigationTitle(document.displayTitle)
            .onReceive(NotificationCenter.default.publisher(for: .rviewOpenFile)) { note in
                if let url = note.object as? URL { document.open(url: url) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .rviewReload)) { _ in
                document.reload()
            }
            .onReceive(NotificationCenter.default.publisher(for: .rviewToggleTheme)) { _ in
                themeOverride = (effectiveTheme == .dark) ? .light : .dark
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
}
