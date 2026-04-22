# Release Playbook

End-to-end steps for cutting a public release of Babel.

## Prerequisites (one-time setup)

### 1. Sparkle EdDSA keypair — already set up

The project's `SUPublicEDKey` is committed to `project.yml`. The
matching private key lives in the current maintainer's Keychain under
the item *"https://sparkle-project.org"* (Account: `ed25519`). If you
inherit maintenance, you inherit that keychain entry.

**Losing the private key means losing the ability to update existing
installs.** Export it once with `security export` into an encrypted
backup, or keep a recent Time Machine snapshot of the login keychain.
Rotating the key requires shipping a new `SUPublicEDKey` via a fresh
download (users would have to reinstall), so avoid it.

To re-generate from scratch (first-time only, or after a key loss):

```bash
SPARKLE_ARTIFACTS=$(find ~/Library/Developer/Xcode/DerivedData \
  -path "*SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys" 2>/dev/null | head -1)
"$SPARKLE_ARTIFACTS"
```

Paste the printed base64 string into `project.yml` (`SUPublicEDKey`),
re-run `xcodegen generate`, commit.

### 2. Apple Developer signing — two paths

**Path A — paid Apple Developer Program ($99/yr).** You get a
*Developer ID Application* certificate, which is what Gatekeeper
accepts on any Mac, plus access to notarization. This is the right
path for a public launch.

- In Xcode → Settings → Accounts → Manage Certificates, add an
  *Apple Development* **and** a *Developer ID Application* cert.
- Create an App Store Connect API key for `notarytool`
  (*Users and Access → Integrations → App Store Connect API*). Keep
  the `.p8` file + key ID + issuer ID somewhere safe; they stand in
  for an Apple ID password.

**Path B — free Personal Team (current state).** You can only sign
with an *Apple Development* cert, which the user has to right-click
→ *Open* through the first time. No notarization.

Everything below uses Path A names; swap "Developer ID Application" for
"Apple Development" if you're on Path B.

## Every release — step-by-step

### 1. Bump the version

In `project.yml`:

```yaml
settings:
  base:
    MARKETING_VERSION: "0.2.0"      # what users see
    CURRENT_PROJECT_VERSION: "2"    # monotonic build counter
```

Regenerate the project:

```bash
xcodegen generate
```

### 2. Build the Release configuration

```bash
xcodebuild -project Babel.xcodeproj -scheme Babel -configuration Release \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation -skipMacroValidation \
  clean build
```

The signed app lands in
`~/Library/Developer/Xcode/DerivedData/Babel-*/Build/Products/Release/Babel.app`.

### 3. Re-sign with Developer ID (or Apple Development)

`scripts/resign.sh` picks the first *Apple Development* identity by
default. For public releases, override with the Developer ID identity:

```bash
BABEL_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  scripts/resign.sh
```

Verify:

```bash
codesign --verify --deep --strict --verbose=2 \
  ~/Library/Developer/Xcode/DerivedData/Babel-*/Build/Products/Release/Babel.app
spctl -a -t exec -vv \
  ~/Library/Developer/Xcode/DerivedData/Babel-*/Build/Products/Release/Babel.app
```

### 4. Package into a DMG

```bash
scripts/build-dmg.sh
```

Produces `release/Babel-<version>.dmg`.

### 5. Notarize (Path A only)

```bash
xcrun notarytool submit release/Babel-0.2.0.dmg \
  --key ~/private/apple-notary-key.p8 \
  --key-id ABC123DEF4 \
  --issuer 12345678-1234-1234-1234-1234567890ab \
  --wait
xcrun stapler staple release/Babel-0.2.0.dmg
```

### 6. Sign the appcast entry

```bash
"$SPARKLE_DIR/bin/sign_update" release/Babel-0.2.0.dmg
```

Prints an `sparkle:edSignature="…"` attribute. Add it to `appcast.xml`
alongside the download URL, size, version, and release notes.

### 7. Publish

1. Create a new GitHub Release: tag `v0.2.0`, attach the DMG.
2. Commit and push `appcast.xml` (Sparkle fetches it from
   `https://raw.githubusercontent.com/matinsaurralde/babel/main/appcast.xml`).
3. Sanity check: open the previously shipped build and click
   *Check for Updates…* — it should find the new release.

## Running users cling-to-old-builds fire drill

If a release ever ships with a broken `SUPublicEDKey` or a DMG whose
Developer ID doesn't match Sparkle's `SUExpectedTeamID`, users' copies
will refuse the update silently. Publish the next release under the
same team ID and key; Sparkle will pick it up on the next check. There
is no push channel.

## First release (v0.1.0)

The first release is a chicken-and-egg: previous builds have no
Sparkle feed to check. Ship v0.1.0 as a **download** (DMG on the
GitHub Releases page, linked from the README); every subsequent
release can flow through Sparkle.
