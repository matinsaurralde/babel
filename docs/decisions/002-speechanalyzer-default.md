# ADR-002: Apple SpeechAnalyzer as the default transcription engine

**Status**: Accepted
**Date**: 2026-04-16

## Context

Babel needs a local, on-device transcription backend that's fast, accurate, and feels native on Apple Silicon. Three serious options exist as of April 2026:

- **Apple SpeechAnalyzer** (new in macOS 26) — on-device, model-managed by the OS, ~45 ms per second of audio on M-series.
- **WhisperKit** — Whisper (tiny → large-v3) running via CoreML on the Neural Engine. Battle-tested, used by Superwhisper. MIT licensed.
- **MLX-Swift Whisper / Parakeet** — fastest raw numbers on Apple Silicon, but Swift bindings are still bleeding-edge (FluidInference's Parakeet Swift port pivoted to CoreML mid-2025).

## Decision

Default to **Apple SpeechAnalyzer** for the Fast and Balanced modes. Reserve the Accurate mode for WhisperKit `large-v3-turbo`, which lands in v1.0. MLX is deferred to v1.1+ pending Swift-binding maturity.

## Alternatives Considered

- **WhisperKit across all three modes** — consistent engine, proven (Superwhisper), Sonoma-compatible. Rejected because (a) the first-launch model download is ~300 MB–1.5 GB before the user has transcribed a single word, and (b) SpeechAnalyzer is genuinely faster for short-utterance dictation, which is the 90% case.
- **MLX-Swift primary** — strongest "Apple Silicon-native" narrative. Rejected because Parakeet-Swift isn't production-quality yet, and MLX-Whisper-Swift is a thin wrapper over MLX that doesn't wrap easily in a clean engine protocol.

## Consequences

- First launch is instant — SpeechAnalyzer models are managed by macOS and don't require a per-app download.
- The Accurate mode has a distinct identity (WhisperKit + large-v3-turbo) rather than being "same engine with knobs turned".
- Babel carries a `TranscriptionEngine` protocol from day one so a future WhisperKit or MLX backend is a drop-in replacement.
- SpeechAnalyzer requires the user grant Speech Recognition permission in addition to Microphone — not free, but on-device. This trade is documented in the onboarding flow.
