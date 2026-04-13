# peek

> markdown, natively.

A light, native macOS markdown viewer. WebKit does the heavy lifting; the rest is just taste.

```
$ peek README.md
$ peek ./docs
```

- **Tiny.** ~2 MB binary. No Electron, no Chromium, no Node.
- **Native.** ⌘F, smooth scroll, print, VoiceOver, fullscreen — because it's all WebKit.
- **Beautiful.** Serif body, sans headings, real vertical rhythm. Dark mode auto-switches.
- **Fast.** Sub-300 ms cold start on Apple Silicon.

## Install

Requires macOS 14+ and Swift 5.9+.

```bash
git clone https://github.com/rsdrahat/peek.git
cd peek
make app
open .build/peek.app
```

Symlink it for shell use:

```bash
ln -s "$(pwd)/.build/peek.app/Contents/MacOS/peek" /usr/local/bin/peek
peek README.md
```

First launch is Gatekeeper-blocked (not notarized pre-1.0). Right-click → **Open** → **Open anyway**, once.

## Use

```bash
peek README.md          # open a file
peek ./docs             # open a folder — sidebar tree
open -a peek file.md    # via Finder
# or drag a .md file / folder onto the window
```

## Keys

| Key | Action |
|---|---|
| `⌘O` / `⌥⌘O` | Open file / open folder |
| `⌘R` | Reload |
| `⌘F` | Find in page |
| `⌘⇧O` | Toggle outline (TOC) |
| `⌘⇧D` | Toggle light/dark |
| `⌘=` / `⌘-` / `⌘0` | Zoom in / out / reset |
| `⌘P` / `⌘⇧E` | Print / export PDF |

Vim-style sidebar nav: `j`/`k` move, `h`/`l` collapse/expand, `enter` open, `gg`/`G` top/bottom.

## Develop

```bash
make build            # swift build -c release
make test             # tests
make app              # .build/peek.app
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the stack rationale and project layout.

## Roadmap

- **v0.1 MVP** — render, watch, theme, GFM, drag-drop ✅
- **v0.2 Polish** — window state, scroll memory, zoom, print/export ✅
- **v0.3 Folder mode** — sidebar tree, keyboard nav 🚧
- **v0.4 Editor** — split view, live preview
- **v0.5 Themes** — custom CSS, font presets

[All issues →](https://github.com/rsdrahat/peek/issues)

## License

MIT.
