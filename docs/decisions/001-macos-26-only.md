# ADR-001: macOS 26 Tahoe only, no backwards compatibility

**Status**: Accepted
**Date**: 2026-04-16

## Context

macOS 26 (Tahoe) ships with two APIs that define the Babel experience: `SpeechAnalyzer` — the new on-device transcription framework that's ~55% faster than Whisper large-v3-turbo — and `.glassEffect()`, the native Liquid Glass modifier in SwiftUI. Supporting macOS 14/15 means either:

1. hand-rolling a Liquid-Glass-looking material via `NSVisualEffectView` + custom shaders on older versions, and
2. shipping WhisperKit as a second transcription backend for users without SpeechAnalyzer.

Both add code paths, testing surface, and visual inconsistency.

## Decision

Ship for **macOS 26 and later only**. Minimum deployment target `26.0`. No conditional compilation, no `#available` branches for the primary feature path.

## Alternatives Considered

- **macOS 14+ (Sonoma)**: largest addressable audience. Rejected because the whole point of Babel is *native Apple-design-forward*; approximating Liquid Glass on Sonoma produces an app that feels like it's pretending to be what it isn't.
- **macOS 15+ (Sequoia)**: middle ground. Still requires Liquid Glass fallback code. Not worth the split.

## Consequences

- Smaller initial addressable market — but macOS adoption of a new major is fast, and Babel is pre-alpha open-source, not chasing install counts.
- Single code path, zero branching for UI materials or the transcription engine.
- Contributors onboard onto a smaller, sharper codebase.
- Users on Sonoma/Sequoia are pointed at the alternatives (Superwhisper, Wispr Flow) in the README. If demand materializes, a "babel-legacy" branch targeting macOS 14+ could be forked — but it is explicitly not the main line.
