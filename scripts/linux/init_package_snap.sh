#!/usr/bin/env bash
set -euo pipefail

VERSION="$(cargo metadata --format-version 1 --no-deps | python3 -c 'import json, sys; print(json.load(sys.stdin)["packages"][0]["version"])')"
PACKAGE_NAME="framebolt"
ARCH="x86_64"
APP_ID="com.framebolt.Framebolt"

echo "Packaging ${PACKAGE_NAME} ${VERSION}..."

rm -rf snap

mkdir -p snap/gui
mkdir -p snap/local

cp target/release/framebolt-desktop \
    snap/framebolt

cp framebolt.png \
    snap/gui/framebolt.png

cat > snap/gui/${APP_ID}.desktop <<EOF
[Desktop Entry]
Name=Framebolt
Comment=Framebolt
Exec=framebolt
Icon=\${SNAP}/meta/gui/framebolt.png
Terminal=false
Type=Application
Categories=AudioVideo;
EOF

cat > snap/snapcraft.yaml <<EOF
name: framebolt
base: core24
version: '${VERSION}'
summary: Framebolt
description: |
  A media application built with Rust and GStreamer.

grade: stable
confinement: strict

apps:
  framebolt:
    command: framebolt
    desktop: meta/gui/${APP_ID}.desktop
    plugs:
      - audio-playback
      - audio-record
      - camera
      - desktop
      - desktop-legacy
      - home
      - opengl
      - wayland
      - x11

parts:
  framebolt:
    plugin: dump
    source: .
    source-type: local
    organize:
      framebolt: bin/framebolt
EOF

mkdir -p dist
