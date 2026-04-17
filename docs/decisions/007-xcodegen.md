# ADR-007: XcodeGen for the Xcode project

**Status**: Accepted
**Date**: 2026-04-16

## Context

Xcode project files (`.xcodeproj/project.pbxproj`) are a binary-ish serialized plist that changes on every file add, renamed group, or build-setting tweak. Merge conflicts are routine and unreadable. Three approaches:

- Commit the `.xcodeproj` and live with the noise.
- Use [Tuist](https://tuist.dev) — full-featured, Swift-authored manifests, cache/remote-build features.
- Use [XcodeGen](https://github.com/yonaskolb/XcodeGen) — a YAML `project.yml` generates the `.xcodeproj` on demand.

## Decision

Use **XcodeGen**. The `.xcodeproj` is gitignored; the source of truth is `project.yml`.

## Alternatives Considered

- **Commit the `.xcodeproj`**: noise in every PR, manual resolution of pbxproj merge conflicts, no way to review "what changed in the project structure" beyond guessing from a thousand-line diff. Rejected.
- **Tuist**: powerful, Swift-authored manifests, but more ceremony than Babel needs right now. For a 1.5k LoC greenfield, a 30-line YAML is enough. Revisit if/when the project splits into modules.

## Consequences

- Every contributor runs `xcodegen generate` once after cloning. Documented in the README.
- Adding a file = dropping it into `Babel/` under the right subfolder; no Xcode UI interaction required.
- `project.yml` doubles as *documentation*: deployment target, entitlements, Info.plist keys, SPM deps, build settings — all in one readable file.
- PRs touching project structure produce a readable YAML diff instead of a pbxproj wall.
- Tradeoff: project files regenerate freshly, which means custom Xcode-UI settings (schemes with non-default options, breakpoints shared as-project-data) need to be expressed in `project.yml` or they're lost. Fine for a small codebase.
