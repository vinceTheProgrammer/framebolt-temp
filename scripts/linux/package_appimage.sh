#!/usr/bin/env bash

set -euo pipefail

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)
        APPIMAGE_ARCH="x86_64"
        ;;
    aarch64)
        APPIMAGE_ARCH="aarch64"
        ;;
    *)
        echo "error: unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

echo "==> Packaging AppImage for $ARCH"

rm -rf AppDir

mkdir -p AppDir/usr/bin

cp target/release/framebolt-desktop \
    AppDir/usr/bin/framebolt

chmod +x AppDir/usr/bin/framebolt

mkdir -p dist

cd dist

linuxdeploy \
    --appdir ../AppDir \
    --executable ../AppDir/usr/bin/framebolt \
    --output appimage \
    --create-desktop-file \
    --icon-file ../framebolt.png

cd ..

echo "==> AppImage output"

ls -lah dist/

test -n "$(find dist -maxdepth 1 -name "*.AppImage" -print -quit)"

echo "==> Created AppImage for $APPIMAGE_ARCH"