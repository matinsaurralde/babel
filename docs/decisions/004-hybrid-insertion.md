# ADR-004: Hybrid AX-first, pasteboard-fallback text insertion

**Status**: Accepted
**Date**: 2026-04-16

## Context

"Insert the transcript into the focused app" sounds simple. On macOS, it is not:

- **Accessibility API (AXUIElement)**: write directly to the focused field via `AXSelectedText` or `AXValue`. Clean — no pasteboard side-effects. Breaks on most Electron apps, many web inputs, and anything that doesn't expose an accessible text field (a lot, in practice).
- **Pasteboard + synthesized ⌘V**: copy the text, post a Cmd-V CGEvent. Works in ~99% of apps because it uses the app's normal paste handler. Clobbers the user's clipboard.
- **Accessibility API only**: cleanest when it works; silently drops the transcript when it doesn't.
- **Pasteboard only**: universal, but steals the clipboard every single time.

## Decision

Try the **Accessibility API first**; on failure, fall back to **pasteboard + ⌘V**. In the pasteboard path, save the user's current clipboard contents before writing, and restore them 300 ms after the paste.

```
final text → AccessibilityInserter.tryInsert
           → on false → PasteboardInserter.insert
                      → save pb → write → ⌘V → restore pb (300 ms later)
```

## Alternatives Considered

- **Pure AX**: user-hostile when it silently drops the text in Electron-based apps (Slack, Notion, VS Code before AX improvements). Unacceptable as a dictation app.
- **Pure pasteboard**: works everywhere, but a dictation session every 30 seconds means your clipboard is effectively unusable. Unacceptable.
- **CGEvent keystroke simulation (type each character)**: works in secure fields, but visibly slow on long transcripts and can interleave with the user's typing.

## Consequences

- Reliability jumps to ~99% of apps (measured against AX-only ~60%).
- The 300 ms clipboard-restore window is a small risk — if the user copies something else during that interval, we'd overwrite it. Accepted tradeoff; most users aren't copying mid-dictation.
- Two small modules (`AccessibilityInserter`, `PasteboardInserter`) behind a thin `TextInserter` orchestrator. Unit-testable. A future `DirectKeystrokeInserter` can slot in for secure fields.
- Secure-input contexts (Terminal with secure keyboard entry, password fields) still fail silently. The roadmap includes detecting these and showing a toast: "Can't insert here — transcript copied to clipboard."
