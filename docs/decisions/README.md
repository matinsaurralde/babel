# Architecture Decision Records

This directory captures the **why** behind Babel's non-obvious technical choices.

Each ADR is a short Markdown file that describes one decision: the context it was made in, the choice, the alternatives considered, and the consequences we accept. They are meant to survive beyond the PR discussion that produced them, and to give new contributors a map of the trade-off landscape without having to reconstruct it from git history.

## Index

1. [macOS 26 Tahoe only, no backwards compatibility](./001-macos-26-only.md)
2. [Apple SpeechAnalyzer as the default transcription engine](./002-speechanalyzer-default.md)
3. [Push-to-hold over press-to-toggle](./003-push-to-hold.md)
4. [Hybrid AX-first, pasteboard-fallback text insertion](./004-hybrid-insertion.md)
5. [NSPanel + NSHostingController for the floating pill](./005-nspanel-for-pill.md)
6. [Distribute outside the Mac App Store](./006-no-app-store.md)
7. [XcodeGen for the Xcode project](./007-xcodegen.md)
8. [Swift 6 strict concurrency from day zero](./008-swift-6-strict-concurrency.md)

## Writing a new ADR

1. Pick the next number. Filenames are `NNN-slug.md`.
2. Start with this frontmatter:

   ```markdown
   # ADR-NNN: <Short imperative title>

   **Status**: Proposed | Accepted | Superseded by ADR-NNN
   **Date**: YYYY-MM-DD
   ```

3. Cover: **Context**, **Decision**, **Alternatives Considered**, **Consequences**. Keep each section to a handful of paragraphs — if you need more, the decision probably needs splitting.
4. Open a PR that includes the ADR alongside the implementation change. Update `README.md` at the project root if the decision surfaces to users.

ADRs are not laws. If the context changes, supersede with a new ADR and mark the old one `Superseded by ADR-NNN`.
