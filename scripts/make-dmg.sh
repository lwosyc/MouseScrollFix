#!/usr/bin/env bash
#
# Builds a distributable disk image:
#
#   ./scripts/make-dmg.sh
#
# Produces build/MouseScrollFix-<version>.dmg containing the app, a shortcut to
# /Applications, and a short bilingual read-me.
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MouseScrollFix"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)"
DMG_PATH="build/$APP_NAME-$VERSION.dmg"
STAGE="build/dmg-stage"

# Regenerate the icon when it is missing (it is a build artefact, not source).
if [[ ! -f Resources/AppIcon.icns ]]; then
    echo "==> Generating app icon"
    CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.modulecache}" \
    SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$PWD/.modulecache}" \
    TMPDIR="${TMPDIR:-$PWD/.tmp}" \
        swift scripts/make-icon.swift
fi

./scripts/build-app.sh release

echo "==> Staging DMG contents"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "build/$APP_NAME.app" "$STAGE/"
# A symlink to /Applications is what makes the drag-and-drop install work.
ln -s /Applications "$STAGE/Applications"

cp "Resources/Read me.txt" "$STAGE/Read me.txt"

# Finder window layout: the app on the left, Applications on the right, the read-me
# underneath. Written straight into .DS_Store, so this needs no permission to control
# Finder and works in headless/sandboxed builds.
echo "==> Writing Finder layout"
python3 scripts/dmg-layout.py "$STAGE" \
    --window 220 160 560 400 \
    --icon "MouseScrollFix.app" 150 180 \
    --icon "Applications" 410 180 \
    --icon "Read me.txt" 280 320

echo "==> Creating $DMG_PATH"
rm -f "$DMG_PATH"
if ! hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH" 2>"${TMPDIR:-/tmp}/msf-hdiutil.log"
then
    cat "${TMPDIR:-/tmp}/msf-hdiutil.log" >&2
    cat >&2 <<'EOF'

error: hdiutil could not create the disk image.

hdiutil goes through the DiskImages framework, which a restricted sandbox (agent
shell, container, some CI runners) does not allow. Run this script from a normal
Terminal window instead — nothing else in the build needs special access.

If hdiutil is unavailable entirely, build/MouseScrollFix.app is already a complete,
launchable app: distribute that instead, for example

    ditto -c -k --keepParent build/MouseScrollFix.app build/MouseScrollFix.app.zip
EOF
    exit 1
fi

rm -rf "$STAGE"

echo "==> Verifying"
hdiutil verify "$DMG_PATH" >/dev/null

SIZE="$(du -h "$DMG_PATH" | cut -f1)"
cat <<EOF

Built: $DMG_PATH ($SIZE)

Install: open the image, drag MouseScrollFix into Applications, launch it, and grant
the Accessibility permission when the window asks for it.

Want a background picture in the window (arrow + captions)? Run

    ./scripts/dmg-add-background.sh

once: it does everything except the final ⌘J in Finder, which cannot be automated
without granting a script permission to control Finder.
EOF
