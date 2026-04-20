#!/usr/bin/env bash
# Re-sign a freshly built Babel.app with a stable Apple Development identity
# so the code-signature hash stays identical across rebuilds. Without this,
# every rebuild is treated by TCC as a different app and every permission
# (Microphone, Speech Recognition, Input Monitoring, Accessibility) has to
# be re-granted manually.
#
# Usage:  scripts/resign.sh [path/to/Babel.app]
# Env override: BABEL_SIGN_IDENTITY  (default resolves the first available
#              "Apple Development:" identity in the login keychain)
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
  APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 8 -name "Babel.app" -path "*/Debug/*" 2>/dev/null | head -1)
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "resign.sh: Babel.app not found. Build first or pass path as argument." >&2
  exit 1
fi

IDENTITY="${BABEL_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning \
    | awk -F'"' '/Apple Development/ { print $2; exit }')
fi
if [[ -z "$IDENTITY" ]]; then
  echo "resign.sh: no Apple Development identity in the keychain. Open Xcode → Settings → Accounts → Manage Certificates → + Apple Development." >&2
  exit 1
fi

ENTITLEMENTS="$(cd "$(dirname "$0")/.." && pwd)/Babel/Resources/Babel.entitlements"

echo "resign.sh: signing $APP"
echo "resign.sh: identity = $IDENTITY"

# Xcode leaves behind SwiftUI preview scaffolding (`__preview.dylib`) and a
# `Babel.cstemp` stub referenced by the prior signature; both break `--verify`
# after re-signing. Remove them and the prior `_CodeSignature/` so codesign
# rebuilds the manifest from scratch.
rm -f "$APP/Contents/MacOS/__preview.dylib"
rm -f "$APP/Contents/MacOS/Babel.cstemp"
rm -rf "$APP/Contents/_CodeSignature"

codesign --force --deep --sign "$IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  --options runtime \
  --timestamp=none \
  "$APP"

codesign --verify --verbose=2 "$APP"
echo "resign.sh: done"
