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
# Find native Linux release binaries.
#
# The release should publish:
#
#   framebolt-x86_64
#   framebolt-arm64
#
# Arch Linux uses:
#
#   x86_64
#   aarch64
#
# for these two architectures respectively.
###############################################################################

echo "==> Finding native Linux release binaries..."

X86_64_BINARY_NAME="framebolt-x86_64"
AARCH64_BINARY_NAME="framebolt-arm64"

X86_64_BINARY_URL="$(
    jq -r \
        --arg name "$X86_64_BINARY_NAME" \
        '.assets[]
         | select(.name == $name)
         | .browser_download_url' \
        <<<"$RELEASE_JSON"
)"

if [[ -z "$X86_64_BINARY_URL" || "$X86_64_BINARY_URL" == "null" ]]; then
    echo "error: release does not contain ${X86_64_BINARY_NAME}" >&2
    echo >&2
    echo "Available release assets:" >&2
    jq -r '.assets[].name' <<<"$RELEASE_JSON" >&2
    exit 1
fi

AARCH64_BINARY_URL="$(
    jq -r \
        --arg name "$AARCH64_BINARY_NAME" \
        '.assets[]
         | select(.name == $name)
         | .browser_download_url' \
        <<<"$RELEASE_JSON"
)"

if [[ -z "$AARCH64_BINARY_URL" || "$AARCH64_BINARY_URL" == "null" ]]; then
    echo "error: release does not contain ${AARCH64_BINARY_NAME}" >&2
    echo >&2
    echo "Available release assets:" >&2
    jq -r '.assets[].name' <<<"$RELEASE_JSON" >&2
    exit 1
fi

echo "    x86_64:"
echo "      binary: ${X86_64_BINARY_NAME}"
echo "      url:    ${X86_64_BINARY_URL}"

echo "    aarch64:"
echo "      binary: ${AARCH64_BINARY_NAME}"
echo "      url:    ${AARCH64_BINARY_URL}"

###############################################################################
# Download release binaries so we can generate real SHA256 checksums.
###############################################################################

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

echo "==> Downloading ${X86_64_BINARY_NAME} for checksum..."

curl -fL \
    --retry 3 \
    --retry-delay 2 \
    -o "${TMP_DIR}/${X86_64_BINARY_NAME}" \
    "$X86_64_BINARY_URL"

X86_64_BINARY_SHA256="$(
    sha256sum "${TMP_DIR}/${X86_64_BINARY_NAME}" |
        awk '{print $1}'
)"

echo "    sha256: ${X86_64_BINARY_SHA256}"

echo "==> Downloading ${AARCH64_BINARY_NAME} for checksum..."

curl -fL \
    --retry 3 \
    --retry-delay 2 \
    -o "${TMP_DIR}/${AARCH64_BINARY_NAME}" \
    "$AARCH64_BINARY_URL"

AARCH64_BINARY_SHA256="$(
    sha256sum "${TMP_DIR}/${AARCH64_BINARY_NAME}" |
        awk '{print $1}'
)"

echo "    sha256: ${AARCH64_BINARY_SHA256}"

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

    cp res/icons/framebolt.png "$dir/framebolt.png"
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
arch=('x86_64' 'aarch64')
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
        --locked
}

package() {
    cd "\${srcdir}/framebolt-\${pkgver}"

    install -Dm755 \
        target/release/framebolt-desktop \
        "\${pkgdir}/usr/bin/framebolt"

    install -Dm644 \
        "\${srcdir}/res/meta/aur.desktop" \
        "\${pkgdir}/usr/share/applications/framebolt.desktop"

    install -Dm644 \
        "\${srcdir}/res/icons/framebolt.png" \
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
# Native prebuilt Linux release binaries.
#
# x86_64  -> framebolt-x86_64
# aarch64 -> framebolt-arm64
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
arch=('x86_64' 'aarch64')
url='https://github.com/${REPO}'

# TODO: replace with the actual SPDX license used by the project.
license=('custom')

depends=(
    'gstreamer'
    'glib2'
)

provides=('framebolt')
conflicts=('framebolt' 'framebolt-git')

source_x86_64=(
    '${X86_64_BINARY_NAME}::${X86_64_BINARY_URL}'
)

source_aarch64=(
    '${AARCH64_BINARY_NAME}::${AARCH64_BINARY_URL}'
)

source=(
    'framebolt.desktop'
    'framebolt.png'
)

sha256sums_x86_64=(
    '${X86_64_BINARY_SHA256}'
)

sha256sums_aarch64=(
    '${AARCH64_BINARY_SHA256}'
)

sha256sums=(
    'SKIP'
    'SKIP'
)

package() {
    local binary_name

    case "\${CARCH}" in
        x86_64)
            binary_name='${X86_64_BINARY_NAME}'
            ;;
        aarch64)
            binary_name='${AARCH64_BINARY_NAME}'
            ;;
        *)
            echo "error: unsupported architecture: \${CARCH}" >&2
            return 1
            ;;
    esac

    install -Dm755 \
        "\${srcdir}/\${binary_name}" \
        "\${pkgdir}/usr/bin/framebolt"

    install -Dm644 \
        "\${srcdir}/res/meta/aur.desktop" \
        "\${pkgdir}/usr/share/applications/framebolt.desktop"

    install -Dm644 \
        "\${srcdir}/res/icons/framebolt.png" \
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
arch=('x86_64' 'aarch64')
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
        --locked
}

package() {
    cd "\${srcdir}/framebolt"

    install -Dm755 \
        target/release/framebolt-desktop \
        "\${pkgdir}/usr/bin/framebolt"

    install -Dm644 \
        "\${srcdir}/res/meta/aur.desktop" \
        "\${pkgdir}/usr/share/applications/framebolt.desktop"

    install -Dm644 \
        "\${srcdir}/res/icons/framebolt.png" \
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
echo "Release:       ${RELEASE_TAG}"
echo "Version:       ${RELEASE_VERSION}"
echo "Main:          ${MAIN_SHA}"
echo
echo "x86_64 binary: ${X86_64_BINARY_NAME}"
echo "x86_64 SHA256: ${X86_64_BINARY_SHA256}"
echo
echo "aarch64 binary: ${AARCH64_BINARY_NAME}"
echo "aarch64 SHA256: ${AARCH64_BINARY_SHA256}"