# Changelog

## 0.3.2 — Homebrew fixes

- Resource bundle now resolves correctly inside the signed `.app`
- `peek` CLI works when installed via Homebrew cask

## 0.3.1 — Launch path

- `open -a peek file.md` opens the file (not the welcome page)
- CLI shim resolves symlinks back to the real bundle path

## 0.3 — Folder mode

- Sidebar file tree with vim-style keyboard nav (`j` `k` `h` `l`)
- Breadcrumb bar
- Open Recent menu
- Inter-document links resolve across the folder

## 0.2 — Polish

- Window state persists across launches
- Per-file scroll memory (SHA-256 keyed)
- Zoom (`⌘=` / `⌘-` / `⌘0`)
- Print and PDF export

## 0.1 — MVP

- Open, render, live-watch
- Auto light/dark
- GFM basics, drag-drop
- 27 tests, green
