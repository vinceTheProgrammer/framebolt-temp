#!/usr/bin/env bash
set -euo pipefail

VERSION="$(cargo metadata --format-version 1 --no-deps | python3 -c 'import json, sys; print(json.load(sys.stdin)["packages"][0]["version"])')"
PACKAGE_NAME="framebolt" 
ARCH="$(uname -m)"

echo "Packaging ${PACKAGE_NAME} ${VERSION}..."

rm -rf deb

mkdir -p deb/DEBIAN
mkdir -p deb/usr/bin
mkdir -p deb/usr/share/applications
mkdir -p deb/usr/share/icons/hicolor/96x96/apps

cp target/release/framebolt-desktop \
    deb/usr/bin/framebolt

cp framebolt.png \
    deb/usr/share/icons/hicolor/96x96/apps/framebolt.png

cat > deb/usr/share/applications/framebolt.desktop <<'EOF'
[Desktop Entry]
Name=Framebolt
Comment=Framebolt
Exec=framebolt
Icon=framebolt
Terminal=false
Type=Application
Categories=AudioVideo;
EOF

cat > deb/DEBIAN/control <<EOF
Package: ${PACKAGE_NAME} 
Version: ${VERSION}
Section: video
Priority: optional
Architecture: ${ARCH}
Maintainer: Framebolt
Description: Framebolt
 A media application built with Rust and GStreamer.
Depends: libgstreamer1.0-0
EOF

mkdir -p dist

OUTPUT="dist/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

dpkg-deb --build --root-owner-group deb "${OUTPUT}"

echo "Created ${OUTPUT}"