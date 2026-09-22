#!/usr/bin/env bash
set -euo pipefail

rm -rf AppDir

mkdir -p AppDir/usr/bin
cp target/release/framebolt-desktop AppDir/usr/bin/framebolt

mkdir -p dist
cd dist

linuxdeploy \
    --appdir ../AppDir \
    --executable ../AppDir/usr/bin/framebolt \
    --output appimage \
    --create-desktop-file \
    --icon-file ../framebolt.png

cd ..