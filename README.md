# rview

A light, native markdown viewer for macOS. Built on SwiftUI + WebKit.

- **Light.** Single-digit MB binary. No Electron, no Chromium.
- **Native.** WKWebView brings Cmd+F find, smooth scroll, accessibility, print, and real fullscreen for free.
- **Beautiful.** Typographic defaults out of the box. Serif body, sans headings, tasteful dark mode.
- **Fast to open.** Sub-300ms cold start on Apple Silicon.

## Install

Requires macOS 13+ and Swift 5.9+.

```bash
git clone https://github.com/rsdrahat/rview.git
cd rview
make app
open .build/rview.app
```

## Use

```bash
rview README.md            # open a file
open -a rview README.md    # via Finder
# or drag a .md file onto the window
```

## Keys

| Key | Action |
|---|---|
| ⌘O | Open file |
| ⌘R | Reload |
| ⌘F | Find in page |
| ⌘⇧D | Toggle dark/light |
| ⌃⌘F | Toggle fullscreen (system default) |

## Status

Pre-alpha. See [ROADMAP](https://github.com/rsdrahat/rview/issues).

## License

MIT
