#!/usr/bin/env bash
#
# Builds the DMG with a real background picture — everything except the one step that
# has to happen in Finder.
#
#   ./scripts/dmg-add-background.sh              # all in one: builds, mounts, waits, compresses
#   ./scripts/dmg-add-background.sh --prepare    # build + mount + open Finder, then exit
#   ./scripts/dmg-add-background.sh --finalize   # eject the mounted image and compress it
#
# Why a manual step exists at all: Finder can only use a background *image* through an
# alias record stored in .DS_Store, and the Carbon Alias Manager that produced those
# records has been removed from recent macOS. The remaining options are to let a script
# drive Finder through Apple Events (which asks for permission to control Finder) or to
# set the picture by hand. This script does all the mechanical work and leaves you the
# one click. The --prepare/--finalize split exists so the manual step can be done in a
# different session than the build.
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
MOUNT_POINT="/Volumes/$VOLNAME"

mode="${1:-interactive}"

require_swift() {
    if ! command -v swift >/dev/null 2>&1; then
        echo "error: swift was not found. Install the Xcode Command Line Tools:" >&2
        echo "       xcode-select --install" >&2
        exit 1
    fi
}

build_stage() {
    require_swift

    if [[ ! -f "$BACKGROUND" ]]; then
        echo "==> Generating the background picture"
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
}

create_and_mount() {
    echo "==> Creating a writable image"
    rm -f "$RW_IMAGE" "$FINAL_IMAGE"
    hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW_IMAGE" >/dev/null

    echo "==> Mounting"
    hdiutil attach -readwrite -nobrowse "$RW_IMAGE" >/dev/null
    if [[ ! -d "$MOUNT_POINT" ]]; then
        echo "error: $RW_IMAGE mounted, but $MOUNT_POINT is missing" >&2
        exit 1
    fi
}

print_steps() {
    cat <<EOF

────────────────────────────────────────────────────────────────────────────
 Осталось 20 секунд ручной работы — задать фон в Finder
────────────────────────────────────────────────────────────────────────────

  1. Окно образа уже открыто в Finder (том «$VOLNAME»).

  2. Нажмите ⌘J  (Вид → Показать параметры вида / View → Show View Options).

  3. Внизу панели: «Фон» → «Картинка» (Background → Picture), затем
     перетащите этот файл в окошко предпросмотра рядом:

         $BACKGROUND

  4. Там же: «Размер значков» = 128, а «Упорядочить» / «Сортировка»
     оставьте как есть (None) — иначе Finder перебьёт позиции иконок.

  5. Иконки можно подвинуть, если хотите другое расположение.

  6. Закройте окно образа и вернитесь в терминал.

EOF
}

finalize() {
    if [[ ! -d "$MOUNT_POINT" ]]; then
        echo "error: «$VOLNAME» не смонтирован — нечего отключать." >&2
        echo "       Запустите: ./scripts/dmg-add-background.sh --prepare" >&2
        exit 1
    fi

    echo "==> Отключаю том и сжимаю образ"
    sync
    hdiutil detach "$MOUNT_POINT" >/dev/null
    hdiutil convert "$RW_IMAGE" -format UDZO -imagekey zlib-level=9 -o "$FINAL_IMAGE" >/dev/null
    rm -f "$RW_IMAGE"

    echo "==> Проверяю"
    hdiutil verify "$FINAL_IMAGE" >/dev/null

    cat <<EOF

Готово: $FINAL_IMAGE ($(du -h "$FINAL_IMAGE" | cut -f1))

Фон, раскладка иконок и размер окна теперь внутри образа: открываете — окно
сразу выглядит как надо, со стрелкой на Applications.
EOF
}

case "$mode" in
    --prepare)
        build_stage
        create_and_mount
        open "$MOUNT_POINT"
        print_steps
        cat <<EOF
Когда закончите — запустите:

    cd "$PWD"
    ./scripts/dmg-add-background.sh --finalize

EOF
        ;;
    --finalize)
        finalize
        ;;
    interactive)
        build_stage
        create_and_mount
        open "$MOUNT_POINT"
        print_steps
        read -r -p "Нажмите Return, когда фон выставлен... " _
        finalize
        ;;
    *)
        echo "usage: $0 [--prepare | --finalize]" >&2
        exit 2
        ;;
esac
