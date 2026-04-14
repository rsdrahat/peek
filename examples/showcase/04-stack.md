# The stack

How peek stays under 2 MB.

## Ingredients

```swift
import SwiftUI
import WebKit
import Markdown  // swift-markdown, cmark-gfm under the hood
```

That's it. Three imports, one dependency.

## Why WebKit

We considered three options for rendering:

1. **AttributedString + TextKit** — native, but no code highlighting, no tables-as-first-class, no CSS layering
2. **A custom layout engine** — fun, but we'd spend two years reimplementing CSS
3. **WKWebView** — free. Ships with macOS. `⌘F`, print, smooth scroll, accessibility — all delegated

Option 3 won on the second afternoon.

## Render pipeline

```
markdown source
      ↓
swift-markdown AST
      ↓
HTMLEmitter (~200 lines)
      ↓
WKWebView + base.css + highlight.min.js
      ↓
pixels
```

No intermediate JSON. No virtual DOM. No template engine. The AST walks emit HTML strings directly.

## What we're *not* shipping

| Library | Size | Reason |
|---|---|---|
| Electron | 150 MB | it's Chromium |
| Tauri | 8 MB | still a webview + a runtime |
| React | 130 KB | no client app to hydrate |
| Tailwind | 40 KB | one hand-tuned stylesheet is better |

## Binary size budget

CI fails the build if `peek` exceeds **10 MB**. It currently lives at **~1.9 MB**.

```yaml
- name: Binary size budget (≤ 10 MB)
  run: |
    bytes=$(stat -f%z .build/release/peek)
    if [ "$bytes" -gt "$((10 * 1024 * 1024))" ]; then
      echo "::error::Binary exceeded 10 MB budget"
      exit 1
    fi
```

The budget is the feature.
