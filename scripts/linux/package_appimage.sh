#!/usr/bin/env bash
set -euo pipefail

rm -rf AppDir

mkdir -p AppDir/usr/bin
cp target/release/framebolt-desktop AppDir/usr/bin/framebolt

mkdir -p dist
cd dist

# need to use modified version with the bundled strip executable removed because the libs on my system that it tries to strip are too new or some shit
# /tmp/linuxdeploy-modified/linuxdeploy-system-strip.AppImage
linuxdeploy \
    --appdir ../AppDir \
    --executable ../AppDir/usr/bin/framebolt \
    --output appimage \
    --create-desktop-file \
    --icon-file ../framebolt.png

cd ..