#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
BUILD_ROOT="$PROJECT_ROOT/build-release"
BUILT_APP="$BUILD_ROOT/Build/Products/Release/Voke.app"
DIST_ROOT="$PROJECT_ROOT/dist"
DMG_PATH="$DIST_ROOT/Voke.dmg"
CHECKSUM_PATH="$DIST_ROOT/Voke.dmg.sha256"
SIGNING_HELPER="$PROJECT_ROOT/scripts/ensure-local-signing-identity.sh"
CERTIFICATE_NAME="Voke Local Development"

cd "$PROJECT_ROOT"
"$SIGNING_HELPER" >/dev/null

LOGIN_KEYCHAIN="$(security default-keychain -d user | sed -E 's/^[[:space:]]*"//; s/"[[:space:]]*$//')"
SIGNING_IDENTITY="$({
  security find-identity -v -p codesigning "$LOGIN_KEYCHAIN" \
    | awk -v name="$CERTIFICATE_NAME" 'index($0, "\"" name "\"") { print $2; exit }'
})"

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
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  build

if [[ ! -d "$BUILT_APP" ]]; then
  print -u2 "Build product not found: $BUILT_APP"
  exit 1
fi

PACKAGE_ROOT="$(mktemp -d /tmp/voke-dmg.XXXXXX)"
VERIFY_MOUNT="$(mktemp -d /tmp/voke-verify.XXXXXX)"
STAGED_APP="$PACKAGE_ROOT/Voke.app"

cleanup() {
  hdiutil detach "$VERIFY_MOUNT" -quiet 2>/dev/null || true
  rm -rf "$PACKAGE_ROOT" "$VERIFY_MOUNT"
}
trap cleanup EXIT

ditto "$BUILT_APP" "$STAGED_APP"
codesign --force --deep --options runtime --timestamp=none \
  --keychain "$LOGIN_KEYCHAIN" \
  --sign "$SIGNING_IDENTITY" \
  --identifier com.dolphin.ai-command-controller \
  "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

ln -s /Applications "$PACKAGE_ROOT/Applications"
cp "$PROJECT_ROOT/site/安装说明.txt" "$PACKAGE_ROOT/首次打开说明.txt"

mkdir -p "$DIST_ROOT"
rm -f "$DMG_PATH" "$CHECKSUM_PATH"
hdiutil create \
  -volname "Voke" \
  -srcfolder "$PACKAGE_ROOT" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

shasum -a 256 "$DMG_PATH" | sed 's#  .*/#  #' > "$CHECKSUM_PATH"

hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$VERIFY_MOUNT" -quiet
codesign --verify --deep --strict --verbose=2 "$VERIFY_MOUNT/Voke.app"
lipo -archs "$VERIFY_MOUNT/Voke.app/Contents/MacOS/Voke"
hdiutil detach "$VERIFY_MOUNT" -quiet

print "Created test package: $DMG_PATH"
print "Checksum: $(cat "$CHECKSUM_PATH")"
print "This package uses a local self-signed identity and is not notarized."
