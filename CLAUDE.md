# CLAUDE.md

Guidance for Claude working on this repository.

## Product

**rview** is a native macOS markdown viewer. The product promise is exactly three things, in order: **light, native, beautiful**. Every change should be justifiable against at least one of these.

- **Light** means binary under 10 MB, cold start under 300 ms, RSS under 80 MB for typical documents. No Electron, no Chromium, no Node, no Python sidecar. If a dependency adds more than ~300 KB to the binary, it needs a written justification.
- **Native** means "indistinguishable from an Apple app." Cmd+F, print, accessibility, smooth scroll, proper fullscreen, dark mode auto-switch, VoiceOver — these must all work, and they work because we delegate to WebKit/AppKit, not because we reimplement them.
- **Beautiful** means typographic defaults that a designer would ship. Serif body, sans headings, proper vertical rhythm, restrained color, no chrome noise.

## Stack & why

- **SwiftUI + AppKit bridge** for the window shell. SwiftUI where it shines, AppKit where it has to (NSOpenPanel, file open events, document types).
- **WKWebView** as the renderer. This is the single most important architectural choice in the project. We render markdown to HTML and hand it to WebKit. We do not render text ourselves. Every feature request should first be evaluated as "can WebKit already do this?" — almost always, the answer is yes.
- **[Ink](https://github.com/JohnSundell/Ink)** (pure Swift, MIT) for markdown → HTML. Chosen for zero C deps and small surface. Known limitation: not 100% GFM-spec-compliant. If we outgrow it, the migration target is `swift-cmark`/`swift-markdown` — see the open tracking issue before acting.
- **Swift Package Manager only.** No CocoaPods, no Carthage. No Xcode project committed to git; the `.app` is built from `Package.swift` via `make app`.

## What lives where

```
Sources/rview/
  App.swift              SwiftUI @main, command menus, notification names
  AppDelegate.swift      CLI args, openFile event, NSOpenPanel
  MainWindow.swift       Root SwiftUI view, theme override, drag-drop
  MarkdownDocument.swift @MainActor model: url → parsed html, file watch
  MarkdownWebView.swift  NSViewRepresentable wrapping WKWebView + HTML shell
  FileWatcher.swift      DispatchSource-based watcher (one fd per file)
  Resources/
    light.css / dark.css Typographic stylesheets (the product's "face")
Tests/rviewTests/        XCTest; fast, no UI tests yet
Info.plist               Bundle metadata; document types live here
Makefile                 swift build → .app bundling
```

## Rules

### Do
- Prefer WebKit capabilities over Swift code. Find-in-page, printing, zoom, smooth scroll, link handling — these are all WebKit's job.
- Keep `MarkdownDocument` the single source of truth for the current file's state.
- Use `@MainActor` on anything that touches SwiftUI state or AppKit APIs. The file watcher fires on a background queue — always hop to main.
- Treat the CSS files as product surface. Changes there are user-facing design changes and should be reviewed as such.
- When adding a dependency, measure the binary size delta (`ls -l .build/release/rview` before and after) and put it in the PR description.

### Don't
- Don't add a JS framework inside the webview. If you reach for React or Vue, the design has gone wrong. Plain HTML + a little vanilla JS is the ceiling.
- Don't reimplement anything WebKit gives us. We had one crash in inlyne because it rendered text on the GPU instead of using WebKit — that entire class of bug is out of scope here, and we keep it that way.
- Don't add telemetry. No analytics, no "anonymous usage stats," no crash reporting that leaves the device. A local log file is the maximum.
- Don't commit Xcode project files. Anyone should be able to `swift build`.
- Don't let the binary cross 10 MB without a discussion.
- Don't add features behind feature flags unless there is a real rollout reason — this is a desktop app, not a SaaS.

### When unsure
- If a feature request is ambiguous about scope, the answer is the lighter version.
- If a dependency is tempting, first try the standard library.
- If a feature requires a preference, try to find a sensible default that makes the preference unnecessary.

## Build & test

```bash
make build      # swift build -c release
make test       # swift test
make app        # produce .build/rview.app
make run FILE=README.md
```

CI runs `swift build` and `swift test` on macOS latest. Both must be green to merge.

## Versioning & releases

SemVer. `0.x.y` until we ship 1.0. Release = tag + GitHub release with the built `.app` zipped and a SHA256. Notarization is a post-1.0 concern; pre-1.0 users are assumed to right-click → Open.

## Roadmap shape

Sprints land as GitHub milestones:

- **v0.1 MVP** — open, render, watch, theme, GFM basics, drag-drop
- **v0.2 Polish** — persist window state, scroll memory, zoom, print/export
- **v0.3 Folder view** — sidebar file tree, keyboard nav
- **v0.4 Editor** — split view, live preview
- **v0.5 Config & presets** — themes, fonts, custom CSS

Do not blur sprint boundaries without updating the milestones. Editor work does not start before 0.3 ships.

## PR etiquette

- One concern per PR. A typo fix and a new feature are two PRs.
- Screenshots for any CSS or layout change. A side-by-side before/after, not just an "after."
- If you touch `MarkdownWebView.shell(...)`, paste the rendered output of a representative document in the PR.
- Tests for anything in `Renderer`/`MarkdownDocument`. UI doesn't need tests yet; keep it that way until we have a reason.

## Anti-goals

Explicit list of things **rview is not** and will not become:

- Not an editor-first tool. Editing is a later sprint and will remain secondary to viewing.
- Not a knowledge base. No backlinks graph, no daily notes, no plugin API.
- Not cross-platform. macOS only. A Linux/Windows port would mean a different codebase.
- Not a browser. No tabs beyond one-window-per-file. No webview navigation beyond the current document.
