# Architecture

## Product

**peek** is a native macOS markdown viewer. The product promise is exactly three things, in order: **light, native, beautiful**. Every change should be justifiable against at least one of these.

- **Light** means binary under 10 MB, cold start under 300 ms, RSS under 80 MB for typical documents. No Electron, no Chromium, no Node, no Python sidecar. If a dependency adds more than ~300 KB to the binary, it needs a written justification.
- **Native** means "indistinguishable from an Apple app." Cmd+F, print, accessibility, smooth scroll, proper fullscreen, dark mode auto-switch, VoiceOver — these must all work, and they work because we delegate to WebKit/AppKit, not because we reimplement them.
- **Beautiful** means typographic defaults that a designer would ship. Serif body, sans headings, proper vertical rhythm, restrained color, no chrome noise.

## Stack & why

- **SwiftUI + AppKit bridge** for the window shell. SwiftUI where it shines, AppKit where it has to (NSOpenPanel, file open events, document types).
- **WKWebView** as the renderer. This is the single most important architectural choice in the project. We render markdown to HTML and hand it to WebKit. We do not render text ourselves. Every feature request should first be evaluated as "can WebKit already do this?" — almost always, the answer is yes.
- **[swift-markdown](https://github.com/apple/swift-markdown)** + cmark-gfm for markdown → HTML. Zero C-deps beyond cmark, GFM-compliant, Apple-maintained.
- **Swift Package Manager only.** No CocoaPods, no Carthage. No Xcode project committed to git; the `.app` is built from `Package.swift` via `make app`.

## Layout

```
Sources/peek/
  App.swift              SwiftUI @main, command menus, notification names
  AppDelegate.swift      CLI args, openFile event, NSOpenPanel
  MainWindow.swift       Root SwiftUI view, theme override, drag-drop
  MarkdownDocument.swift @MainActor model: url → parsed html, file watch
  MarkdownWebView.swift  NSViewRepresentable wrapping WKWebView + HTML shell
  FolderBrowser.swift    @MainActor model: directory → tree of nodes
  FileTreeSidebar.swift  Persistent sidebar for folder mode
  TOCSidebar.swift       Outline sidebar (⌘⇧O)
  FileWatcher.swift      DispatchSource-based watcher (one fd per file)
  Resources/
    base.css / light.css / dark.css   Typographic stylesheets (the product's "face")
Tests/peekTests/         XCTest; fast, no UI tests
Info.plist               Bundle metadata; document types live here
Makefile                 swift build → .app bundling
docs/                    GitHub Pages site
```

## Rules

### Do
- Prefer WebKit capabilities over Swift code. Find-in-page, printing, zoom, smooth scroll, link handling — these are all WebKit's job.
- Keep `MarkdownDocument` the single source of truth for the current file's state.
- Use `@MainActor` on anything that touches SwiftUI state or AppKit APIs. The file watcher fires on a background queue — always hop to main.
- Treat the CSS files as product surface. Changes there are user-facing design changes and should be reviewed as such.
- When adding a dependency, measure the binary size delta and put it in the PR description.

### Don't
- Don't add a JS framework inside the webview. If you reach for React or Vue, the design has gone wrong. Plain HTML + a little vanilla JS is the ceiling.
- Don't reimplement anything WebKit gives us.
- Don't add telemetry. No analytics, no "anonymous usage stats," no crash reporting that leaves the device. A local log file is the maximum.
- Don't commit Xcode project files.
- Don't let the binary cross 10 MB without discussion.
- Don't add features behind feature flags unless there is a real rollout reason.

### When unsure
- If a feature request is ambiguous about scope, the answer is the lighter version.
- If a dependency is tempting, first try the standard library.
- If a feature requires a preference, try to find a sensible default that makes the preference unnecessary.

## Anti-goals

Explicit list of things **peek is not** and will not become:

- Not an editor. peek is a viewer; edit in your editor, view in peek. There is no editing sprint.
- Not a knowledge base. No backlinks graph, no daily notes, no plugin API.
- Not cross-platform. macOS only. A Linux/Windows port would mean a different codebase.
- Not a browser. No tabs beyond one-window-per-file. No webview navigation beyond the current document.
