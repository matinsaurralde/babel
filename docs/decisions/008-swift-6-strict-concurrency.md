# ADR-008: Swift 6 strict concurrency from day zero

**Status**: Accepted
**Date**: 2026-04-16

## Context

Babel is a small but thread-heavy app: a C-callback-driven CGEventTap on the main runloop, an AVAudioEngine tap on a dedicated audio thread, an async transcription engine that runs detached, and SwiftUI views that mutate `@Observable` state — all of which converge on the UI.

Swift 6 ships `SWIFT_STRICT_CONCURRENCY=complete`, which flips many concurrency diagnostics from warnings to errors at compile time.

## Decision

Enable **complete strict concurrency** in `project.yml`. Every actor boundary is deliberate, every `Sendable` is justified, every `@unchecked Sendable` has a comment explaining the invariant.

## Alternatives Considered

- **Swift 5 / `minimal` concurrency checking**: ships faster short-term, defers the hard bug class (data races between the audio thread and MainActor) to runtime. Given that one of the first crash reports on this codebase was a runtime isolation assertion in `SFSpeechRecognizer`'s callback, runtime-only enforcement would have been much worse. Rejected.
- **`targeted` concurrency checking**: middle ground. Rejected as false economy — the codebase is small enough to pay the full cost now.

## Consequences

- Small patterns like the CGEventTap C callback required structural thought: the callback is nonisolated, so we extract Sendable scalars (`keycode: Int64`, `flagsRaw: UInt64`) before hopping to `MainActor.assumeIsolated`.
- `AVAudioPCMBuffer` isn't Sendable-annotated upstream, so `AudioCapture` imports AVFoundation with `@preconcurrency` and wraps the converter's one-shot `done` flag in a reference type (`ConvertOnce`) to satisfy the capture checker.
- Apple's privacy callbacks (e.g. `SFSpeechRecognizer.requestAuthorization`) fire on arbitrary queues. `Permissions` is intentionally **not** `@MainActor`; pinning it broke the runtime with a `_swift_task_checkIsolatedSwift` assertion. The callsites that need MainActor (opening System Settings, showing the AX prompt) use explicit `await MainActor.run {}`.
- Contributors starting a new file: default to no actor annotation, add `@MainActor` only for types that touch AppKit / SwiftUI state.
