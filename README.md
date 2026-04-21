# Babel

**Dictation for macOS that never leaves your Mac.**

Hold a key. Speak. Release. The text appears in whatever app you're in — browser, terminal, code editor, Slack. No cloud. No telemetry. No account. No subscription.

Built natively for macOS 26 Tahoe: Apple **SpeechAnalyzer** for on-device transcription, native **Liquid Glass** for the UI, and the **Apple Neural Engine** doing the work your M-series chip was designed for.

```
hold ⌥            speak            release
   ┌──────────────────────────────────────┐
   │  ●  Listening…                       │   ← floats over every app
   └──────────────────────────────────────┘
```

## Why "Babel"

Jorge Luis Borges — the Argentine writer — imagined a library containing *every possible book*: every combination of letters, every text that has been written or ever could be. Babel — the dictation app — is a narrower version of that library: every word **you** are about to say, turned into text you can place anywhere, on a machine that forgets the audio the moment it's done with it.

## Why another dictation app

| | Babel | Superwhisper | Wispr Flow | Apple Dictation |
|---|:---:|:---:|:---:|:---:|
| On-device only | ✓ | ✓ | ✗ (cloud) | ✓ |
| Open source | ✓ (MIT) | ✗ | ✗ | ✗ |
| Free | ✓ | $15/mo | $12/mo | ✓ |
| Works in any app | ✓ | ✓ | ✓ | partial |
| Latency | <400 ms | ~600 ms | ~1 s | ~500 ms |
| Liquid Glass UI | ✓ | mimicked | ✗ | — |

**Privacy is a design decision, not a checkbox.** Babel has no server. No opt-out telemetry — because there is nothing to opt out of. The mic audio flows into Apple's on-device `SpeechAnalyzer`, produces a string, gets inserted into the focused app, and is gone. We don't even keep the audio in memory past the session.

**Speed is the other pillar.** Push-to-hold gives you one modal gesture. Transcription streams in the background while you're speaking so the final text is ready the instant you release the key. Apple's SpeechAnalyzer on M-series hits ~45 ms/sec of audio — the bottleneck is now how fast you talk.

## Status

**Pre-alpha.** macOS 26 Tahoe and later only. Three modes, all on-device:

- **Fast** — Apple SpeechAnalyzer, no post-processing. <400 ms end-of-speech.
- **Balanced** — SpeechAnalyzer with partial-result streaming.
- **Accurate** — Whisper `large-v3-turbo` via [WhisperKit](https://github.com/argmaxinc/WhisperKit). First use downloads ~1.5 GB from Hugging Face; cached afterwards.

v1.1 will add local LLM post-processing via [Ollama](https://ollama.com) for grammar cleanup and custom vocabulary. v1.2 will add optional BYOK routing to OpenAI / Groq / Cohere for users who want cloud-fast.

## Build from source

```bash
brew install xcodegen
git clone https://github.com/matinsaurralde/babel.git
cd babel
xcodegen generate
open Babel.xcodeproj
```

Or from the command line:

```bash
xcodegen generate
xcodebuild -project Babel.xcodeproj -scheme Babel -configuration Debug build
scripts/resign.sh   # re-sign with your stable Apple Development identity
open ~/Library/Developer/Xcode/DerivedData/Babel-*/Build/Products/Debug/Babel.app
```

Requires **Xcode 26** and **macOS 26** (Tahoe).

### Why the re-sign step?

Xcode's default ad-hoc signature changes on every build, so macOS' TCC
database treats each rebuild as a different app and revokes every
permission. `scripts/resign.sh` post-signs the built `.app` with a
stable Apple Development identity from your login keychain, so the
code-signature hash is identical across rebuilds and permissions stay
granted. Set one up once in Xcode → Settings → Accounts → Manage
Certificates → `+` Apple Development.

## Permissions

Four, all native macOS:

| Permission | Used for |
|---|---|
| Microphone | capture your voice |
| Speech Recognition | run Apple SpeechAnalyzer on-device |
| Input Monitoring | detect the global push-to-hold hotkey |
| Accessibility | paste the transcript into the focused app |

The first launch walks you through each one. Every permission prompts through macOS' native system — Babel never sees the raw grant.

## Default hotkey

**Hold Right Option** to record. Release to insert. Rebinding arrives with v1.0.

## Languages

Babel transcribes in every language your Mac's dictation can. It picks the locale you've set as macOS' system language by default; Settings → General → Dictation Language lets you override the choice.

To add more languages, open **System Settings → Keyboard → Dictation** and enable the ones you want. macOS downloads the on-device model the first time; after that, everything stays local.

## Design decisions

The important choices live as ADRs in [`docs/decisions/`](./docs/decisions). If you're wondering "why did they do X instead of Y", that's where to look. Start with:

- [001 — macOS 26 only, no fallbacks](./docs/decisions/001-macos-26-only.md)
- [002 — Apple SpeechAnalyzer as the default engine](./docs/decisions/002-speechanalyzer-default.md)
- [003 — Push-to-hold over press-to-toggle](./docs/decisions/003-push-to-hold.md)
- [004 — Hybrid AX + paste text insertion](./docs/decisions/004-hybrid-insertion.md)

## Contributing

Babel is MIT-licensed and built in public. Issues and PRs welcome. If you're proposing a non-trivial change, please sketch an ADR in `docs/decisions/` so the discussion stays in the repo.

## License

MIT — see [LICENSE](./LICENSE).

---

*Privacy and speed, by design. — Buenos Aires, 2026*
