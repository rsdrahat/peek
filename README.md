# peek

> the reader markdown has been missing.

Markdown is how software talks to itself now. Every model writes it, every agent parses it, every prompt, spec, and README lives in it — it's the interchange format of the AI stack. And yet in 2026, opening a `.md` file still means an editor with a blinking cursor or a 150 MB browser tab.

peek is a reader. Just a reader. **Light, native, beautiful.**

<p align="center">
  <img src="https://raw.githubusercontent.com/rsdrahat/peek/main/docs/assets/screenshot-hero.png" alt="peek rendering a markdown document with the folder sidebar, table of contents, and breadcrumb bar visible" width="820">
</p>

## Install

```bash
brew install --cask rsdrahat/peek/peek
```

Or grab the zip directly: **[latest release →](https://github.com/rsdrahat/peek/releases/latest)**. Unzip, drop `peek.app` into `/Applications`.

Apple Silicon · macOS 14+ · signed + notarized.

## Build from source

Requires Swift 5.9+.

```bash
git clone https://github.com/rsdrahat/peek.git
cd peek
make app
open .build/peek.app
```

Symlink for shell use:

```bash
ln -s "$(pwd)/.build/peek.app/Contents/MacOS/peek" /usr/local/bin/peek
peek README.md
```

## Why peek

- **Light.** Single-digit megabytes. Sub-300 ms cold start. No Electron, no Chromium, no Node.
- **Native.** Real `NSWindow`, real `⌘`-bindings, real Retina text rendering. `⌘F`, print, smooth scroll, VoiceOver, fullscreen — delegated to WebKit, not reinvented.
- **Beautiful.** Serif body, sans headings, real vertical rhythm. Auto light/dark. Typography tuned for reading, not editing.

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
- **v0.3 Folder mode** — sidebar tree, vim nav, breadcrumb, inter-doc links, Open Recent ✅
- **v0.4 Editor** — split view, live preview
- **v0.5 Themes** — custom CSS, font presets

[All issues →](https://github.com/rsdrahat/peek/issues)

## License

MIT.
