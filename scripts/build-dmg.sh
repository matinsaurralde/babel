#!/usr/bin/env bash
# Build a distribution DMG from the currently built Babel.app.
#
# Usage:  scripts/build-dmg.sh [path/to/Babel.app]
#
# Produces release/Babel-<MARKETING_VERSION>.dmg with:
#   - Babel.app (copy of the built bundle)
#   - Applications (symlink, so users drag into place)
#   - Custom background image from branding/dmg/
#
# The app should already be signed with the target identity before this
# runs — see docs/release.md. This script does NOT sign or notarize.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="${1:-}"
if [[ -z "$APP" ]]; then
  APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 8 -name "Babel.app" -path "*/Release/*" 2>/dev/null | head -1)
  if [[ -z "$APP" ]]; then
    APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 8 -name "Babel.app" -path "*/Debug/*" 2>/dev/null | head -1)
  fi
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "build-dmg.sh: Babel.app not found. Build first, or pass the path as argument." >&2
  exit 1
fi

# Read the marketing version from the built bundle so we can't disagree
# with what xcodebuild stamped.
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG_NAME="Babel-$VERSION.dmg"
BG="branding/dmg/Babel-dmg-660x400.png"

mkdir -p release
rm -f "release/$DMG_NAME"

STAGE=$(mktemp -d -t babel-dmg)
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/Babel.app"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
cp "$BG" "$STAGE/.background/dmg-bg.png"

# Build a read-write DMG first so we can customize the Finder view,
# then convert to compressed read-only.
TEMP_DMG=$(mktemp -u -t babel-dmg)-rw.dmg
hdiutil create -volname "Babel" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$TEMP_DMG" >/dev/null
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | awk '/Volumes/ { print $3 }')

# Best-effort Finder layout. Fails quietly on CI where AppleScript isn't
# available; the DMG still works, just without custom positioning.
osascript <<APPLESCRIPT 2>/dev/null || true
tell application "Finder"
  tell disk "Babel"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 760, 500}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:dmg-bg.png"
    set position of item "Babel.app" of container window to {180, 200}
    set position of item "Applications" of container window to {480, 200}
    update without registering applications
    close
  end tell
end tell
APPLESCRIPT
sync; sleep 1

hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "release/$DMG_NAME" >/dev/null
rm -f "$TEMP_DMG"

echo "build-dmg.sh: wrote release/$DMG_NAME"
ls -lh "release/$DMG_NAME"
