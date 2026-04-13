# CLAUDE.md

Guidance for Claude working on this repository.

## Project

**peek** — a light, native macOS markdown viewer. The product promise is exactly three things, in order: **light, native, beautiful**.

Motivation (canonical, for README/site/PR copy): *Agents don't read .docx. Neither should you.* .docx is a legacy container for humans writing for other humans; markdown is what every LLM writes, every agent parses, every codebase ships — and peek is the view layer for that world. Every change should be justifiable against at least one of the three promise words; the motivation explains *why the world needs this*, the promise explains *what peek is*.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the stack rationale, layout, and rules.

## Build & test

```bash
make build      # swift build -c release
make test       # swift test
make app        # produce .build/peek.app
make run FILE=README.md
```

CI runs `swift build` and `swift test` on macOS latest. Both must be green to merge.

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

## Versioning & releases

SemVer. `0.x.y` until we ship 1.0. Release = tag (`v*.*.*`) + GitHub release with the built `.app` zipped, codesigned with a Developer ID, notarized, and a SHA256 alongside. The release workflow lives in `.github/workflows/release.yml` and runs on tag push.
