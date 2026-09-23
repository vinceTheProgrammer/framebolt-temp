#!/usr/bin/env bash
set -euo pipefail

VERSION="$(cargo metadata --format-version 1 --no-deps | python3 -c 'import json, sys; print(json.load(sys.stdin)["packages"][0]["version"])')"
PACKAGE_NAME="framebolt"
ARCH="$(uname -m)"
DISTRO="fedora"

echo "Packaging ${PACKAGE_NAME} ${VERSION} for Fedora..."

rm -rf rpm

mkdir -p \
    rpm/BUILD \
    rpm/BUILDROOT \
    rpm/RPMS \
    rpm/SOURCES \
    rpm/SPECS \
    rpm/SRPMS

mkdir -p \
    rpm/SOURCES/usr/bin \
    rpm/SOURCES/usr/share/applications \
    rpm/SOURCES/usr/share/icons/hicolor/96x96/apps

cp target/release/framebolt-desktop \
    rpm/SOURCES/usr/bin/framebolt

cp res/icons/framebolt.png \
    rpm/SOURCES/usr/share/icons/hicolor/96x96/apps/framebolt.png

cat > rpm/SOURCES/usr/share/applications/framebolt.desktop <<'EOF'
[Desktop Entry]
Name=Framebolt
Comment=Framebolt
Exec=framebolt
Icon=framebolt
Terminal=false
Type=Application
Categories=AudioVideo;
EOF

tar -czf rpm/SOURCES/framebolt-files.tar.gz \
    -C rpm/SOURCES \
    usr

cat > rpm/SPECS/framebolt.spec <<EOF
Name:           ${PACKAGE_NAME}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Framebolt

%global debug_package %{nil}

License:        Proprietary
URL:            https://github.com/

Source0:        framebolt-files.tar.gz

Requires:       gstreamer1

%description
A media application built with Rust and GStreamer.

%prep
%setup -q -c -T
tar -xzf %{SOURCE0}

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/96x96/apps

cp usr/bin/framebolt \
    %{buildroot}/usr/bin/framebolt

cp usr/share/applications/framebolt.desktop \
    %{buildroot}/usr/share/applications/framebolt.desktop

cp usr/share/icons/hicolor/96x96/apps/framebolt.png \
    %{buildroot}/usr/share/icons/hicolor/96x96/apps/framebolt.png

%files
/usr/bin/framebolt
/usr/share/applications/framebolt.desktop
/usr/share/icons/hicolor/96x96/apps/framebolt.png

%changelog
* $(date '+%a %b %d %Y') Framebolt <framebolt@example.com> - ${VERSION}-1
- Initial package
EOF

mkdir -p dist

rpmbuild \
    --define "_topdir $(pwd)/rpm" \
    -bb rpm/SPECS/framebolt.spec

BUILT_RPM="$(find rpm/RPMS/${ARCH} -name '*.rpm' -type f | head -n 1)"

if [[ -z "${BUILT_RPM}" ]]; then
    echo "ERROR: No Fedora RPM was produced."
    exit 1
fi

OUTPUT="dist/${PACKAGE_NAME}-${VERSION}-1.${ARCH}-fedora.rpm"

cp "${BUILT_RPM}" "${OUTPUT}"

echo "Created ${OUTPUT}"
