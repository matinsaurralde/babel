#!/usr/bin/env bash
# Cut a full release: clean Release build → re-sign → package DMG →
# sign with Sparkle's EdDSA key → update appcast.xml → optionally
# publish to GitHub Releases.
#
# Usage:
#   scripts/release.sh                 # build + package + sign, no publish
#   scripts/release.sh --publish       # also runs `gh release create`
#
# Requires: xcodebuild, xcodegen, scripts/resign.sh, scripts/build-dmg.sh,
# Sparkle's sign_update (resolved into DerivedData via SPM), `gh` CLI
# for --publish.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PUBLISH=0
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
  esac
done

VERSION=$(awk '/^ *MARKETING_VERSION:/ { gsub(/["\x27]/, "", $2); print $2; exit }' project.yml)
if [[ -z "$VERSION" ]]; then
  echo "release.sh: could not read MARKETING_VERSION from project.yml" >&2
  exit 1
fi
DMG="release/Babel-$VERSION.dmg"

echo "release.sh: building v$VERSION"

# 1. Clean Release build.
xcodegen generate >/dev/null
xcodebuild -project Babel.xcodeproj -scheme Babel \
  -configuration Release -destination 'platform=macOS' \
  -skipPackagePluginValidation -skipMacroValidation \
  clean build >/tmp/babel-release-build.log 2>&1
echo "release.sh: xcodebuild OK ($(wc -l </tmp/babel-release-build.log) lines, /tmp/babel-release-build.log)"

RELEASE_APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 8 -name "Babel.app" -path "*/Release/*" 2>/dev/null | head -1)
[[ -d "$RELEASE_APP" ]] || { echo "release.sh: could not find Release Babel.app" >&2; exit 1; }

# 2. Re-sign with the stable Apple Development identity.
scripts/resign.sh "$RELEASE_APP" >/dev/null
echo "release.sh: re-signed $RELEASE_APP"

# 3. Package the DMG.
scripts/build-dmg.sh "$RELEASE_APP" >/dev/null
[[ -f "$DMG" ]] || { echo "release.sh: DMG missing at $DMG" >&2; exit 1; }
DMG_SIZE=$(stat -f%z "$DMG")
echo "release.sh: built $DMG ($DMG_SIZE bytes)"

# 4. Sign the DMG with Sparkle's EdDSA key.
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData \
  -path "*sparkle/Sparkle/bin/sign_update" \
  -not -path "*old_dsa_scripts*" 2>/dev/null | head -1)
[[ -x "$SIGN_UPDATE" ]] || { echo "release.sh: sign_update missing" >&2; exit 1; }
SIG_LINE=$("$SIGN_UPDATE" "$DMG")
echo "release.sh: sparkle signature = $SIG_LINE"

# 5. Show the appcast <item> to paste.
PUB_DATE=$(LC_ALL=C TZ=GMT date "+%a, %d %b %Y %H:%M:%S %z")
cat <<APPCAST_ITEM
release.sh: appcast entry draft — paste into appcast.xml <channel>:

    <item>
      <title>Babel $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <enclosure
        url="https://github.com/matinsaurralde/babel/releases/download/v$VERSION/Babel-$VERSION.dmg"
        $SIG_LINE
      />
    </item>

APPCAST_ITEM

if [[ "$PUBLISH" -eq 1 ]]; then
  echo "release.sh: publishing GitHub Release v$VERSION"
  gh release create "v$VERSION" "$DMG" \
    --title "Babel v$VERSION" \
    --notes-file "docs/release-notes/v$VERSION.md"
  echo "release.sh: release published. Don't forget to update appcast.xml and push."
else
  echo "release.sh: skipped publish (use --publish to run 'gh release create')"
fi
