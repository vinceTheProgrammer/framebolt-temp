#!/usr/bin/env bash
set -euo pipefail

VERSION="$(cargo metadata --format-version 1 --no-deps | python3 -c 'import json, sys; print(json.load(sys.stdin)["packages"][0]["version"])')"

PACKAGE_NAME="framebolt"
APP_ID="com.framebolt.Framebolt"

echo "Preparing ${PACKAGE_NAME} ${VERSION} Snap package..."

rm -rf snap

mkdir -p snap/gui

cat > "snap/gui/${APP_ID}.desktop" <<EOF
[Desktop Entry]
Name=Framebolt
Comment=Framebolt
Exec=framebolt
Icon=framebolt
Terminal=false
Type=Application
Categories=AudioVideo;
EOF

cp framebolt.png \
    "snap/gui/framebolt.png"

cat > snap/snapcraft.yaml <<EOF
name: framebolt
base: core24
version: '${VERSION}'
summary: Framebolt
description: |
  A media application built with Rust and GStreamer.

grade: stable
confinement: strict

source-code:
  - https://github.com/vinceTheProgrammer/framebolt
issues:
  - https://github.com/vinceTheProgrammer/framebolt/issues
website: https://github.com/vinceTheProgrammer/framebolt

apps:
  framebolt:
    command: bin/framebolt
    desktop: gui/${APP_ID}.desktop
    plugs:
      - audio-playback
      - audio-record
      - camera
      - desktop
      - desktop-legacy
      - home
      - network
      - opengl
      - wayland
      - x11

parts:
  framebolt:
    plugin: nil
    source: .
    source-type: local

    build-packages:
      - build-essential
      - curl
      - pkg-config
      - libgstreamer1.0-dev
      - libglib2.0-dev
      - libunwind-dev

    stage-packages:
      - libgstreamer1.0-0
      - libglib2.0-0

    override-build: |
      set -eux

      export RUSTUP_HOME="\$CRAFT_PART_BUILD/.rustup"
      export CARGO_HOME="\$CRAFT_PART_BUILD/.cargo"
      export PATH="\$CARGO_HOME/bin:\$PATH"

      curl --proto '=https' --tlsv1.2 -sSf \
        https://sh.rustup.rs | sh -s -- -y --profile minimal

      cargo build \
        --release \
        -p framebolt-desktop

      install -Dm755 \
        target/release/framebolt-desktop \
        "\$CRAFT_PART_INSTALL/bin/framebolt"
EOF

echo "Created snap/snapcraft.yaml"
echo "Created snap/gui/${APP_ID}.desktop"
echo "Created snap/gui/framebolt.png"
