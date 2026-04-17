# ADR-006: Distribute outside the Mac App Store

**Status**: Accepted
**Date**: 2026-04-16

## Context

Babel needs three permissions that are incompatible with the App Store sandbox:

- **Accessibility** (`AXUIElement` reads/writes on other apps) — explicitly disallowed in sandboxed apps.
- **Input Monitoring** via `CGEventTap` — requires the `com.apple.security.device.microphone` entitlement is fine, but CGEventTap + Accessibility together rule out the sandbox.
- **Reading the frontmost app's bundle ID** via `NSWorkspace` — works sandboxed but is limited.

No realistic dictation app ships on the Mac App Store. Superwhisper, Wispr Flow, TextSniper, Raycast — none of them. The sandbox path is a closed door.

## Decision

Distribute Babel as a **notarized Developer-ID-signed DMG** published on GitHub Releases. Auto-update via [Sparkle 2.x](https://sparkle-project.org). No App Store submission.

## Alternatives Considered

- **App Store with a neutered feature set**: technically possible (drop Accessibility + CGEventTap, use `NSSharingService` or a Services menu extension for insertion). The result wouldn't be a usable dictation app. Rejected.
- **Homebrew Cask only**: great for the dev audience, but excludes the non-technical users who most benefit from "easy local dictation". DMG + Sparkle reaches both.

## Consequences

- Babel must maintain a Developer ID certificate and a notarization pipeline. The repo's CI will script this once a signing identity is provisioned.
- Users grant the four permissions themselves in System Settings — with onboarding guidance from the app — instead of the App Store handling it implicitly.
- `com.apple.security.app-sandbox` is **not** set in the entitlements file. The hardened runtime is still enabled (`ENABLE_HARDENED_RUNTIME=YES`).
- Release artifacts and the Sparkle appcast live in the GitHub Releases tab. A single `Sparkle-signed.xml` describes every version.
