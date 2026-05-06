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
- **v0.4 Search** — file-name fuzzy finder (Cmd+P) and content search across the open folder (Cmd+Shift+F), unified in one lightning-fast palette. Light: native Foundation APIs / NSPredicate, no JS or background indexer for v1; rebuild the file index on folder open. Bar to clear: results visible within a frame of typing on a 10k-file folder.
- **v0.5 Data viewers** — first-class viewers for the textual formats agents emit: JSON + JSONL first (collapsible tree, search, key-path copy, virtualized rows for large files), then YAML and TOML. Same shell, same typography, same window. Extends the motto from "agents don't read .docx" to the whole structured-text surface.
- **v0.6 Config & presets** — themes, fonts, custom CSS

peek is a viewer, not an editor — there is no editor sprint. Edit in your editor, view in peek.

Do not blur sprint boundaries without updating the milestones. Each sprint ships before the next one starts: search work does not start before 0.3 ships, data-viewer work does not start before 0.4 ships, config work does not start before 0.5 ships.

## PR etiquette

- One concern per PR. A typo fix and a new feature are two PRs.
- Screenshots for any CSS or layout change. A side-by-side before/after, not just an "after."
- If you touch `MarkdownWebView.shell(...)`, paste the rendered output of a representative document in the PR.
- Tests for anything in `Renderer`/`MarkdownDocument`. UI doesn't need tests yet; keep it that way until we have a reason.

## Versioning & releases

SemVer. `0.x.y` until we ship 1.0. Release = tag (`v*.*.*`) + GitHub release with the built `.app` zipped, codesigned with a Developer ID, notarized, and a SHA256 alongside. The release workflow lives in `.github/workflows/release.yml` and runs on tag push.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
