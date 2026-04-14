# The Plaintext Manifesto

> Agents don't read `.docx`. Neither should you.

For forty years we taught computers to pretend to be paper. Margins. Page breaks. A cursor blinking inside a simulated letter-sized sheet, waiting to be printed onto something none of us own anymore.

That era is over. The reader is a model. The writer is a model. The format in between is **markdown** — small, grep-able, diff-able, the only thing every LLM agrees on without being told.

**peek** is the view layer for that world. Light. Native. Beautiful.

## Three promises

peek ships when a change can be justified against one of these. Nothing else makes the cut.

| Promise | Means | Measured by |
|---|---|---|
| **Light** | No Electron. No Node. No Chromium. | Single-digit megabytes, sub-300ms cold start |
| **Native** | Real `NSWindow`. Real `⌘`-bindings. Real Retina text. | macOS-native, every pixel |
| **Beautiful** | Typography tuned for reading, not editing | Serif body, sans headings, honest vertical rhythm |

## What it renders

Everything a model is likely to emit:

```swift
// Markdown is the assembly language of thought.
func render(_ document: Markdown) -> HTML {
    let ast = Parser.parse(document)
    return HTMLEmitter().emit(ast)
}
```

```python
def explain(concept: str) -> str:
    """Models write markdown. peek renders it. That's the loop."""
    return f"# {concept}\n\n> Plaintext is the universal donor."
```

Tables. Task lists. Fenced code. GitHub-flavored everything.

- [x] CommonMark + GFM
- [x] Syntax highlighting, 180+ languages
- [x] Auto light/dark, follows system
- [x] Find in page, print, export PDF
- [ ] The things we haven't decided to do yet

## What it refuses

- ❌ A built-in AI assistant you didn't ask for
- ❌ A plugin marketplace
- ❌ Rich-text mode, WYSIWYG, "formatting toolbars"
- ❌ Telemetry

If you want an IDE, use an IDE. peek is a **viewer**. That's the whole job.

## The long bet

Documents are becoming conversational artifacts — written, read, and revised by software. The interchange format won the moment ChatGPT shipped. The only open question left is what you look at while you review, skim, or read.

We think it should feel like this.

---

*peek is MIT-licensed. Built in Swift. Signed and notarized. [github.com/rsdrahat/peek](https://github.com/rsdrahat/peek)*
