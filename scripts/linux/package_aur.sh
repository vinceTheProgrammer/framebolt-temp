#!/usr/bin/env bash
set -euo pipefail

REPO="vinceTheProgrammer/framebolt-temp"
MAIN_BRANCH="main"
OUT_DIR="${1:-aur}"

command -v curl >/dev/null || {
    echo "error: curl is required" >&2
    exit 1
}

command -v jq >/dev/null || {
    echo "error: jq is required" >&2
    exit 1
}

command -v makepkg >/dev/null || {
    echo "error: makepkg is required (run this script on Arch Linux)" >&2
    exit 1
}

command -v sha256sum >/dev/null || {
    echo "error: sha256sum is required" >&2
    exit 1
}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

github_api() {
    curl -fsSL \
        -H 'Accept: application/vnd.github+json' \
        -H 'X-GitHub-Api-Version: 2022-11-28' \
        "$1"
}

echo "==> Fetching latest release information..."

RELEASE_JSON="$(
    github_api \
        "https://api.github.com/repos/${REPO}/releases/latest"
)"

RELEASE_TAG="$(jq -r '.tag_name' <<<"$RELEASE_JSON")"
RELEASE_VERSION="${RELEASE_TAG#v}"

if [[ -z "$RELEASE_TAG" || "$RELEASE_TAG" == "null" ]]; then
    echo "error: unable to determine latest release tag" >&2
    exit 1
fi

echo "    latest release: ${RELEASE_TAG}"
echo "    version:        ${RELEASE_VERSION}"

echo "==> Fetching latest main commit..."

MAIN_JSON="$(
    github_api \
        "https://api.github.com/repos/${REPO}/commits/${MAIN_BRANCH}"
)"

MAIN_SHA="$(jq -r '.sha' <<<"$MAIN_JSON")"

if [[ -z "$MAIN_SHA" || "$MAIN_SHA" == "null" ]]; then
    echo "error: unable to determine latest main commit" >&2
    exit 1
fi

echo "    main: ${MAIN_SHA}"

###############################################################################
# Find the native x86_64 Linux binary.
#
# The Arch CI build/release should publish:
#
#   framebolt-x86_64
#
# We intentionally do NOT use the AppImage here. framebolt-bin is supposed
# to be the native Arch/Linux binary package.
###############################################################################

echo "==> Finding native x86_64 Linux release binary..."

BINARY_NAME="framebolt-x86_64"

BINARY_URL="$(
    jq -r \
        --arg name "$BINARY_NAME" \
        '.assets[]
         | select(.name == $name)
         | .browser_download_url' \
        <<<"$RELEASE_JSON"
)"

if [[ -z "$BINARY_URL" || "$BINARY_URL" == "null" ]]; then
    echo "error: release does not contain ${BINARY_NAME}" >&2
    echo >&2
    echo "Available release assets:" >&2
    jq -r '.assets[].name' <<<"$RELEASE_JSON" >&2
    exit 1
fi

echo "    binary: ${BINARY_NAME}"
echo "    url:    ${BINARY_URL}"

###############################################################################
# Download the release binary so we can generate a real SHA256 checksum.
###############################################################################

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

echo "==> Downloading ${BINARY_NAME} for checksum..."

curl -fL \
    --retry 3 \
    --retry-delay 2 \
    -o "${TMP_DIR}/${BINARY_NAME}" \
    "$BINARY_URL"

BINARY_SHA256="$(
    sha256sum "${TMP_DIR}/${BINARY_NAME}" |
        awk '{print $1}'
)"

echo "    sha256: ${BINARY_SHA256}"

###############################################################################
# Helpers
###############################################################################

write_common_files() {
    local dir="$1"

    mkdir -p "$dir"

    cat > "$dir/.gitignore" <<'EOF'
*.pkg.tar.*
*.src.tar.*
src/
pkg/
EOF
}

write_desktop_files() {
    local dir="$1"

    mkdir -p "$dir"

    cat > "$dir/framebolt.desktop" <<'EOF'
[Desktop Entry]
Name=Framebolt
Comment=Framebolt
Exec=framebolt
Icon=framebolt
Terminal=false
Type=Application
Categories=AudioVideo;
EOF

    cp framebolt.png "$dir/framebolt.png"
}

generate_srcinfo() {
    local dir="$1"

    echo "==> Generating .SRCINFO for ${dir}..."

    (
        cd "$dir"
        makepkg --printsrcinfo > .SRCINFO
    )
}

###############################################################################
# framebolt
#
# Stable release built from source.
###############################################################################

FRAMEBOLT_DIR="${OUT_DIR}/framebolt"

write_common_files "$FRAMEBOLT_DIR"
write_desktop_files "$FRAMEBOLT_DIR"

cat > "$FRAMEBOLT_DIR/PKGBUILD" <<EOF
# Maintainer: Framebolt contributors

pkgname=framebolt
pkgver=${RELEASE_VERSION}
pkgrel=1
pkgdesc='Framebolt'
arch=('x86_64')
url='https://github.com/${REPO}'

# TODO: replace with the actual SPDX license used by the project.
license=('custom')

depends=(
    'gstreamer'
    'glib2'
)

makedepends=(
    'rust'
)

source=(
    "\${pkgname}-\${pkgver}.tar.gz::https://github.com/${REPO}/archive/refs/tags/${RELEASE_TAG}.tar.gz"
    'framebolt.desktop'
    'framebolt.png'
)

sha256sums=(
    'SKIP'
    'SKIP'
    'SKIP'
)

prepare() {
    cd "\${srcdir}/framebolt-\${pkgver}"

    # The workspace package is framebolt-desktop.
    # No source modifications are currently required.
}

build() {
    cd "\${srcdir}/framebolt-\${pkgver}"

    cargo build \
        --release \
        --locked \
        -p framebolt-desktop
}

package() {
    cd "\${srcdir}/framebolt-\${pkgver}"

    install -Dm755 \
        target/release/framebolt-desktop \
        "\${pkgdir}/usr/bin/framebolt"

    install -Dm644 \
        "\${srcdir}/framebolt.desktop" \
        "\${pkgdir}/usr/share/applications/framebolt.desktop"

    install -Dm644 \
        "\${srcdir}/framebolt.png" \
        "\${pkgdir}/usr/share/icons/hicolor/96x96/apps/framebolt.png"

    if [[ -f LICENSE ]]; then
        install -Dm644 LICENSE \
            "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
    elif [[ -f LICENSE.md ]]; then
        install -Dm644 LICENSE.md \
            "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.md"
    elif [[ -f LICENSE.txt ]]; then
        install -Dm644 LICENSE.txt \
            "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.txt"
    fi
}
EOF

###############################################################################
# framebolt-bin
#
# Native prebuilt x86_64 Linux release binary.
###############################################################################

FRAMEBOLT_BIN_DIR="${OUT_DIR}/framebolt-bin"

write_common_files "$FRAMEBOLT_BIN_DIR"
write_desktop_files "$FRAMEBOLT_BIN_DIR"

cat > "$FRAMEBOLT_BIN_DIR/PKGBUILD" <<EOF
# Maintainer: Framebolt contributors

pkgname=framebolt-bin
pkgver=${RELEASE_VERSION}
pkgrel=1
pkgdesc='Framebolt (prebuilt binary)'
arch=('x86_64')
url='https://github.com/${REPO}'

# TODO: replace with the actual SPDX license used by the project.
license=('custom')

depends=(
    'gstreamer'
    'glib2'
)

provides=('framebolt')
conflicts=('framebolt' 'framebolt-git')

source=(
    '${BINARY_NAME}::${BINARY_URL}'
    'framebolt.desktop'
    'framebolt.png'
)

sha256sums=(
    '${BINARY_SHA256}'
    'SKIP'
    'SKIP'
)

package() {
    install -Dm755 \
        "\${srcdir}/${BINARY_NAME}" \
        "\${pkgdir}/usr/bin/framebolt"

    install -Dm644 \
        "\${srcdir}/framebolt.desktop" \
        "\${pkgdir}/usr/share/applications/framebolt.desktop"

    install -Dm644 \
        "\${srcdir}/framebolt.png" \
        "\${pkgdir}/usr/share/icons/hicolor/96x96/apps/framebolt.png"
}
EOF

###############################################################################
# framebolt-git
#
# Latest commit from main.
###############################################################################

FRAMEBOLT_GIT_DIR="${OUT_DIR}/framebolt-git"

write_common_files "$FRAMEBOLT_GIT_DIR"
write_desktop_files "$FRAMEBOLT_GIT_DIR"

cat > "$FRAMEBOLT_GIT_DIR/PKGBUILD" <<EOF
# Maintainer: Framebolt contributors

pkgname=framebolt-git
pkgver=r1.g${MAIN_SHA:0:7}
pkgrel=1
pkgdesc='Framebolt (latest main branch)'
arch=('x86_64')
url='https://github.com/${REPO}'

# TODO: replace with the actual SPDX license used by the project.
license=('custom')

depends=(
    'gstreamer'
    'glib2'
)

makedepends=(
    'git'
    'rust'
)

provides=('framebolt')
conflicts=('framebolt' 'framebolt-bin')

source=(
    'git+https://github.com/${REPO}.git#branch=${MAIN_BRANCH}'
    'framebolt.desktop'
    'framebolt.png'
)

sha256sums=(
    'SKIP'
    'SKIP'
    'SKIP'
)

pkgver() {
    cd "\${srcdir}/framebolt"

    printf 'r%s.g%s\n' \
        "\$(git rev-list --count HEAD)" \
        "\$(git rev-parse --short HEAD)"
}

build() {
    cd "\${srcdir}/framebolt"

    cargo build \
        --release \
        --locked \
        -p framebolt-desktop
}

package() {
    cd "\${srcdir}/framebolt"

    install -Dm755 \
        target/release/framebolt-desktop \
        "\${pkgdir}/usr/bin/framebolt"

    install -Dm644 \
        "\${srcdir}/framebolt.desktop" \
        "\${pkgdir}/usr/share/applications/framebolt.desktop"

    install -Dm644 \
        "\${srcdir}/framebolt.png" \
        "\${pkgdir}/usr/share/icons/hicolor/96x96/apps/framebolt.png"

    if [[ -f LICENSE ]]; then
        install -Dm644 LICENSE \
            "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
    elif [[ -f LICENSE.md ]]; then
        install -Dm644 LICENSE.md \
            "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.md"
    elif [[ -f LICENSE.txt ]]; then
        install -Dm644 LICENSE.txt \
            "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.txt"
    fi
}
EOF

###############################################################################
# Generate .SRCINFO
###############################################################################

generate_srcinfo "$FRAMEBOLT_DIR"
generate_srcinfo "$FRAMEBOLT_BIN_DIR"
generate_srcinfo "$FRAMEBOLT_GIT_DIR"

echo
echo "==> Generated AUR packages:"
find "$OUT_DIR" \
    -mindepth 2 \
    -maxdepth 2 \
    -type f \
    -printf '    %p\n' |
    sort

echo
echo "Release: ${RELEASE_TAG}"
echo "Version: ${RELEASE_VERSION}"
echo "Main:    ${MAIN_SHA}"
echo "Binary:  ${BINARY_NAME}"
echo "SHA256:  ${BINARY_SHA256}"
