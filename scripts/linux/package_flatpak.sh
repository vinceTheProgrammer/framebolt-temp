#!/usr/bin/env bash
set -euo pipefail

VERSION="$(cargo metadata --format-version 1 --no-deps | python3 -c 'import json, sys; print(json.load(sys.stdin)["packages"][0]["version"])')"
PACKAGE_NAME="framebolt"
ARCH="$(uname -m)"
APP_ID="com.framebolt.Framebolt"

echo "Packaging ${PACKAGE_NAME} ${VERSION}..."

rm -rf flatpak flatpak-repo

mkdir -p flatpak

# todo figure out how to best handle the filesystem permission in regards to flatpak sandboxing
cat > flatpak/${APP_ID}.yml <<EOF
app-id: ${APP_ID}
runtime: org.freedesktop.Platform
runtime-version: "24.08"
sdk: org.freedesktop.Sdk
command: framebolt

finish-args:
  - --share=ipc
  - --socket=wayland
  - --socket=fallback-x11
  - --device=dri
  - --filesystem=home

modules:
  - name: framebolt
    buildsystem: simple
    build-commands:
      - install -Dm755 framebolt /app/bin/framebolt
      - install -Dm644 res/icons/framebolt.png /app/share/icons/hicolor/96x96/apps/framebolt.png
      - install -Dm644 ${APP_ID}.desktop /app/share/applications/${APP_ID}.desktop
    sources:
      - type: file
        path: ../target/release/framebolt-desktop
        dest-filename: framebolt
      - type: file
        path: ../res/icons/framebolt.png
      - type: file
        path: ${APP_ID}.desktop
EOF

cat > flatpak/${APP_ID}.desktop <<EOF
[Desktop Entry]
Name=Framebolt
Comment=Framebolt
Exec=framebolt
Icon=${APP_ID}
Terminal=false
Type=Application
Categories=AudioVideo;
EOF

mkdir -p dist

flatpak-builder \
    --force-clean \
    --disable-rofiles-fuse \
    --repo=flatpak-repo \
    flatpak-build \
    "flatpak/${APP_ID}.yml"

OUTPUT="dist/${PACKAGE_NAME}_${VERSION}_${ARCH}.flatpak"

flatpak build-bundle \
    flatpak-repo \
    "${OUTPUT}" \
    "${APP_ID}"

echo "Created ${OUTPUT}"