#!/usr/bin/env bash
#
# Builds the DMG with a real background picture — everything except the one step that
# has to happen in Finder.
#
#   ./scripts/dmg-add-background.sh
#
# Why it is interactive: Finder can only use a background *image* through an alias
# record stored in .DS_Store, and the Carbon Alias Manager that produced those records
# has been removed from recent macOS. The remaining options are to let a script drive
# Finder through Apple Events (which asks for permission to control Finder) or to set
# the picture by hand. This script does all the mechanical work — writable image,
# mounting, layout, compression, verification — and leaves you the one click.
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MouseScrollFix"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)"
VOLNAME="$APP_NAME $VERSION"
STAGE="build/dmg-stage"
RW_IMAGE="build/$APP_NAME-rw.dmg"
FINAL_IMAGE="build/$APP_NAME-$VERSION.dmg"
BACKGROUND="$PWD/Resources/dmg-background.png"

if [[ ! -f "$BACKGROUND" ]]; then
    echo "==> Generating the background picture"
    CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.modulecache}" \
    SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$PWD/.modulecache}" \
    TMPDIR="${TMPDIR:-$PWD/.tmp}" \
        swift scripts/make-dmg-background.swift
fi

./scripts/build-app.sh release

echo "==> Staging"
rm -rf "$STAGE"
mkdir -p "$STAGE/.background"
cp -R "build/$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "Resources/Read me.txt" "$STAGE/Read me.txt"
# Finder can only point at a picture that lives on the volume itself.
cp "$BACKGROUND" "$STAGE/.background/background.png"

echo "==> Writing icon layout"
python3 scripts/dmg-layout.py "$STAGE" \
    --window 220 160 560 400 \
    --icon "$APP_NAME.app" 150 180 \
    --icon "Applications" 410 180 \
    --icon "Read me.txt" 280 320

echo "==> Creating a writable image"
rm -f "$RW_IMAGE" "$FINAL_IMAGE"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW_IMAGE" >/dev/null

MOUNT_POINT="$(hdiutil attach -readwrite -nobrowse "$RW_IMAGE" | tail -1 | awk '{for (i=3; i<=NF; i++) printf "%s%s", $i, (i<NF ? " " : "")}')"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
    echo "error: could not mount $RW_IMAGE" >&2
    exit 1
fi

echo "==> Opening $MOUNT_POINT in Finder"
open "$MOUNT_POINT"

cat <<EOF

────────────────────────────────────────────────────────────────────────────
 Set the background picture (about 20 seconds)
────────────────────────────────────────────────────────────────────────────

  1. The disk image window is now open in Finder.

  2. Press ⌘J  (View → Show View Options).

  3. At the bottom of that panel, choose  Background → Picture,
     then drag this file onto the little preview well next to it:

         $BACKGROUND

     (You can drag it straight from this path; no need to reveal hidden files.)

  4. While you are there: set "Icon size" to 128 and leave
     "Arrange" / "Sort by" as  None — otherwise Finder will override the icon
     positions the script just wrote.

  5. Move the icons if you like the arrangement differently.

  6. Close the window, then come back here and press Return.

EOF

read -r -p "Press Return when the picture is set... " _

echo "==> Ejecting and compressing"
sync
hdiutil detach "$MOUNT_POINT" >/dev/null
hdiutil convert "$RW_IMAGE" -format UDZO -imagekey zlib-level=9 -o "$FINAL_IMAGE" >/dev/null
rm -f "$RW_IMAGE"

echo "==> Verifying"
hdiutil verify "$FINAL_IMAGE" >/dev/null

cat <<EOF

Built: $FINAL_IMAGE ($(du -h "$FINAL_IMAGE" | cut -f1))

The background picture and icon layout are now baked into the image: open it and the
window comes up arranged, with the arrow pointing at Applications.
EOF
