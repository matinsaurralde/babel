# ADR-005: NSPanel + NSHostingController for the floating pill

**Status**: Accepted
**Date**: 2026-04-16

## Context

The pill is the only window Babel shows during active use. It needs to:

- float above every app including full-screen windows,
- never steal focus from the app the user is dictating into,
- be click-through (mouse events pass to the app beneath),
- render SwiftUI content with `.glassEffect()`,
- disappear cleanly when the session ends.

SwiftUI offers `Window` scenes with `.windowLevel(.floating)` + `.windowStyle(.plain)`. AppKit offers `NSPanel` with `.nonactivatingPanel` style plus assorted properties (`becomesKeyOnlyIfNeeded`, `isFloatingPanel`, `hidesOnDeactivate`, `ignoresMouseEvents`).

## Decision

Use an **NSPanel subclass hosting a SwiftUI view via NSHostingController**, created and managed imperatively from `PillWindowController`.

## Alternatives Considered

- **Pure SwiftUI Window scene**: concise but, as of macOS 26, doesn't expose fine-grained control over "never becomes key" (`becomesKeyOnlyIfNeeded`) or click-through (`ignoresMouseEvents`) cleanly. The knobs exist only in AppKit.
- **Full AppKit view (no SwiftUI)**: would work but sacrifices SwiftUI's `.glassEffect()` and the ergonomics of the audio-reactive blob. Overkill for a 240×48 pt window.

## Consequences

- The pill code path is AppKit-first (`NSPanel`, `NSAnimationContext`) with SwiftUI embedded via `NSHostingController` — a pattern that will likely be reused for the onboarding window if it needs to sit over other apps.
- `collectionBehavior` is set to `.canJoinAllSpaces | .fullScreenAuxiliary | .ignoresCycle | .stationary` so the pill follows the user across Spaces and full-screen apps.
- The panel is built lazily on first `show()` and kept alive — `orderOut(nil)` hides it without destroying the NSHostingController. Rebuild cost is zero on subsequent sessions.
