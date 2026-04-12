# rview

A light, native markdown viewer for macOS. Built on SwiftUI + WebKit.

- **Light.** Single-digit MB binary. No Electron, no Chromium.
- **Native.** WKWebView brings Cmd+F find, smooth scroll, accessibility, print, and real fullscreen for free.
- **Beautiful.** Typographic defaults out of the box. Serif body, sans headings, tasteful dark mode.
- **Fast to open.** Sub-300ms cold start on Apple Silicon.

## Install

Requires macOS 14+ (Sonoma) and Swift 5.9+.

```bash
git clone https://github.com/rsdrahat/rview.git
cd rview
make app
open .build/rview.app
```

**First launch:** Because the app isn't notarized yet, Gatekeeper blocks it on double-click. Right-click the app → *Open* → *Open anyway*. You only need to do this once. Notarization is a post-1.0 concern.

To invoke from the command line, symlink the binary:
```bash
ln -s "$(pwd)/.build/rview.app/Contents/MacOS/rview" /usr/local/bin/rview
rview README.md
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

## Develop

```bash
make build            # swift build -c release
make test             # run the test suite
make test-update      # regenerate fixture .expected.html after intentional changes
make test-coverage    # coverage report (release)
make app              # produce .build/rview.app
```

Fixtures live in `Tests/rviewTests/Fixtures/`. When markdown rendering changes intentionally, run `make test-update` and commit the new `.expected.html` files alongside the source change.

## Status

Pre-alpha. See [ROADMAP](https://github.com/rsdrahat/rview/issues).

## License

MIT
