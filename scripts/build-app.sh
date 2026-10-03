#!/usr/bin/env bash
#
# Builds MouseScrollFix.app.
#
# Works with the Command Line Tools alone (no Xcode install required) by building the
# SwiftPM executable and assembling the bundle here. Usage:
#
#   ./scripts/build-app.sh              # release build, ad-hoc signed
#   ./scripts/build-app.sh debug        # debug build
#   MSF_HARDENED=1 ./scripts/build-app.sh   # add the hardened runtime flag
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MouseScrollFix"
CONFIG="${1:-release}"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# SwiftPM needs writable caches, and its own sandbox cannot be applied when this
# script already runs inside a restricted sandbox.
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.modulecache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$PWD/.modulecache}"
export TMPDIR="${TMPDIR:-$PWD/.tmp}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$TMPDIR"

echo "==> Building $APP_NAME ($CONFIG)"

# The icon is a build artefact, not source: regenerate it on a fresh clone so the
# bundle always ends up complete.
if [[ ! -f Resources/AppIcon.icns ]]; then
    echo "==> Generating app icon"
    swift scripts/make-icon.swift
fi

swift build --disable-sandbox -c "$CONFIG" --product "$APP_NAME"

BIN_PATH="$(swift build --disable-sandbox -c "$CONFIG" --show-bin-path)"
EXECUTABLE="$BIN_PATH/$APP_NAME"
if [[ ! -f "$EXECUTABLE" ]]; then
    echo "error: built executable not found at $EXECUTABLE" >&2
    exit 1
fi

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "$APP_BUNDLE/Contents/Info.plist" >/dev/null 2>&1 || true
fi

# An ad-hoc signature is enough for local use. Note that rebuilding changes the
# identity, so macOS may ask for Accessibility again after each rebuild.
CODESIGN_ARGS=(--force --sign - --entitlements Resources/MouseScrollFix.entitlements)
if [[ "${MSF_HARDENED:-0}" == "1" ]]; then
    CODESIGN_ARGS+=(--options runtime)
fi

echo "==> Signing (ad-hoc)"
codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"
codesign --verify --verbose=2 "$APP_BUNDLE" || true

cat <<EOF

Built: $APP_BUNDLE

Next steps
  1. Move it somewhere stable (ideally /Applications) before enabling Launch at Login:
       cp -R "$APP_BUNDLE" /Applications/
  2. Launch it:            open "$APP_BUNDLE"
  3. Click the menu bar icon -> "Grant Accessibility permission…"
  4. Enable the app in System Settings -> Privacy & Security -> Accessibility
     (on recent releases the pane may be called "Device Control and Data Access").
  5. Scroll with the mouse, then with the trackpad, and check the menu bar status.

For a redistributable build, sign with a Developer ID certificate and notarize:
  MSF_HARDENED=1 codesign --force --options runtime --sign "Developer ID Application: …" "$APP_BUNDLE"
  xcrun notarytool submit ... && xcrun stapler staple "$APP_BUNDLE"
EOF
