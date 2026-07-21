#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
BUILD_ROOT="$PROJECT_ROOT/build"
BUILT_APP="$BUILD_ROOT/Build/Products/Release/Voke.app"
INSTALLED_APP="/Applications/Voke.app"
SIGNING_HELPER="$PROJECT_ROOT/scripts/ensure-local-signing-identity.sh"
CERTIFICATE_NAME="Voke Local Development"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ "$INSTALLED_APP" != "/Applications/Voke.app" ]]; then
  print -u2 "Refusing unexpected install target: $INSTALLED_APP"
  exit 1
fi

cd "$PROJECT_ROOT"
"$SIGNING_HELPER" >/dev/null
LOGIN_KEYCHAIN="$(security default-keychain -d user | sed -E 's/^[[:space:]]*\"//; s/\"[[:space:]]*$//')"
SIGNING_IDENTITY="$(
  security find-identity -v -p codesigning "$LOGIN_KEYCHAIN" \
    | awk -v name="$CERTIFICATE_NAME" 'index($0, "\"" name "\"") { print $2; exit }'
)"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  print -u2 "Stable Voke signing identity was not found."
  exit 1
fi

xcodegen generate
xcodebuild \
  -project Voke.xcodeproj \
  -scheme Voke \
  -configuration Release \
  -derivedDataPath "$BUILD_ROOT" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$BUILT_APP" ]]; then
  print -u2 "Build product not found: $BUILT_APP"
  exit 1
fi

STAGING_ROOT="$(mktemp -d /tmp/voke-install.XXXXXX)"
trap 'rm -rf "$STAGING_ROOT"' EXIT
STAGED_APP="$STAGING_ROOT/Voke.app"

ditto "$BUILT_APP" "$STAGED_APP"
codesign --force --deep --options runtime --timestamp=none \
  --keychain "$LOGIN_KEYCHAIN" \
  --sign "$SIGNING_IDENTITY" \
  --identifier com.dolphin.ai-command-controller \
  "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

pkill -x Voke 2>/dev/null || true

if [[ -d "$INSTALLED_APP" ]]; then
  "$LSREGISTER" -u "$INSTALLED_APP" 2>/dev/null || true
  mv "$INSTALLED_APP" "$STAGING_ROOT/previous-Voke.app"
fi
mv "$STAGED_APP" "$INSTALLED_APP"

touch "$INSTALLED_APP"
"$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true
"$LSREGISTER" -gc >/dev/null 2>&1 || true
"$LSREGISTER" -f "$INSTALLED_APP"
killall sharedfilelistd 2>/dev/null || true
killall iconservicesagent 2>/dev/null || true
killall Dock 2>/dev/null || true

open "$INSTALLED_APP"
print "Installed and opened with stable local signature: $INSTALLED_APP"
