# ADR-003: Push-to-hold over press-to-toggle

**Status**: Accepted
**Date**: 2026-04-16

## Context

Dictation apps have two activation models:

- **Push-to-hold**: hold the hotkey while speaking. Release to stop + insert. Like a walkie-talkie.
- **Press-to-toggle**: tap once to start, tap again to stop. Hands free while dictating long passages.

Babel is positioned around short, intent-driven dictation — a commit message, a Slack reply, a commit subject line — more than long-form drafting.

## Decision

Ship **push-to-hold only** for v1.0. The default key is **Right Option**. Both edges of the keypress are meaningful: down starts the session, up finalizes and inserts.

## Alternatives Considered

- **Press-to-toggle**: better for long-form dictation, but introduces end-of-utterance ambiguity (how does the app know you're done?) and requires either a timeout or VAD, both of which add latency and surprise.
- **Configurable per-user, both modes**: rejected for v1.0 to keep the interaction model sharp. The code path is isolated in `GlobalHotkey` + `AppCoordinator.handlePress/handleRelease` and can be extended.

## Consequences

- One gesture, one mental model. No "wait, is it recording?" — if you're not holding, it's not recording.
- Users doing long dictations hold the key the whole time, which works but is less comfortable than toggle. Accepted tradeoff; toggle mode is on the roadmap after v1.2.
- The pill visually reflects the hold state (listening → processing → inserting), reinforcing the "you're in control" feedback loop.
- Right Option was chosen as the default because it's almost never used for anything else on modern Mac keyboards — no conflict with Cmd-chord shortcuts, and it's reachable without hand repositioning.
