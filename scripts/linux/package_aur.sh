```bash
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
    echo "error: makepkg is required (install pacman/makepkg on Arch Linux)" >&2
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
RELEASE_JSON="$(github_api "https://api.github.com/repos/${REPO}/releases/latest")"

RELEASE_TAG="$(jq -r '.tag_name' <<<"$RELEASE_JSON")"
RELEASE_VERSION="${RELEASE_TAG#v}"

if [[ -z "$RELEASE_TAG" || "$RELEASE_TAG" == "null" ]]; then
    echo "error: unable to determine latest release tag" >&2
    exit 1
fi

echo "    latest release: ${RELEASE_TAG}"
echo "    version:        ${RELEASE_VERSION}"

echo "==> Fetching latest main commit..."
MAIN_JSON="$(github_api "https://api.github.com/repos/${REPO}/commits/${MAIN_BRANCH}")"

MAIN_SHA="$(jq -r '.sha' <<<"$MAIN_JSON")"

if [[ -z "$MAIN_SHA" || "$MAIN_SHA" == "null" ]]; then
    echo "error: unable to determine latest main commit" >&2
    exit 1
fi

echo "    main: ${MAIN_SHA}"

###############################################################################
# Discover the Linux binary release asset.
#
# We prefer common Linux binary/archive names and x86_64/amd64 variants.
# If the release has exactly one plausible Linux asset, use it.
###############################################################################

echo "==> Finding Linux release binary..."

mapfile -t LINUX_ASSETS < <(
    jq -r '
        .assets[]
        | select(
            (.name | ascii_downcase | test(
                "(linux|x86_64|amd64)"
            ))
            and
            (.name | ascii_downcase | test(
                "\\.(tar\\.gz|tgz|tar\\.xz|tar\\.zst|zip|appimage|bin)$"
            ))
        )
        | .name + "\t" + .browser_download_url
    ' <<<"$RELEASE_JSON"
)

if (( ${#LINUX_ASSETS[@]} == 0 )); then
    echo "error: no Linux release asset found." >&2
    echo >&2
    echo "Available release assets:" >&2
    jq -r '.assets[].name' <<<"$RELEASE_JSON" >&2
    exit 1
fi

if (( ${#LINUX_ASSETS[@]} > 1 )); then
    # Prefer an x86_64/amd64 asset, then a plain linux asset.
    BINARY_ASSET="$(
        printf '%s\n' "${LINUX_ASSETS[@]}" |
            grep -Ei '(x86_64|amd64)' |
            head -n1 ||
            true
    )"

    if [[ -z "$BINARY_ASSET" ]]; then
        BINARY_ASSET="${LINUX_ASSETS[0]}"
    fi
else
    BINARY_ASSET="${LINUX_ASSETS[0]}"
fi

BINARY_NAME="${BINARY_ASSET%%$'\t'*}"
BINARY_URL="${BINARY_ASSET#*$'\t'}"

echo "    binary: ${BINARY_NAME}"

###############################################################################
# Helpers
###############################################################################

write_common_metadata() {
    local dir="$1"
    local pkgname="$2"
    local pkgver="$3"

    mkdir -p "$dir"

    cat > "$dir/.gitignore" <<'EOF'
*.pkg.tar.*
*.src.tar.*
src/
pkg/
EOF

    cat > "$dir/LICENSE" <<'EOF'
This file is intentionally left as a placeholder.

The PKGBUILD installs the upstream project's license from the source
repository. It is kept here only if the AUR package requires a local
license file in the future.
EOF
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

write_common_metadata "$FRAMEBOLT_DIR" framebolt "$RELEASE_VERSION"

cat > "$FRAMEBOLT_DIR/PKGBUILD" <<EOF
# Maintainer: Framebolt contributors
pkgname=framebolt
pkgver=${RELEASE_VERSION}
pkgrel=1
pkgdesc='Framebolt'
arch=('x86_64')
url='https://github.com/${REPO}'
license=('MIT')
depends=()
makedepends=('rust')
source=("\${pkgname}-\${pkgver}.tar.gz::https://github.com/${REPO}/archive/refs/tags/${RELEASE_TAG}.tar.gz")
sha256sums=('SKIP')

build() {
    cd "\${srcdir}/framebolt-\${pkgver}"

    cargo build --release --locked
}

package() {
    cd "\${srcdir}/framebolt-\${pkgver}"

    install -Dm755 "target/release/framebolt" \
        "\${pkgdir}/usr/bin/framebolt"

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
# Latest prebuilt x86_64 Linux release.
###############################################################################

FRAMEBOLT_BIN_DIR="${OUT_DIR}/framebolt-bin"

write_common_metadata "$FRAMEBOLT_BIN_DIR" framebolt-bin "$RELEASE_VERSION"

cat > "$FRAMEBOLT_BIN_DIR/PKGBUILD" <<EOF
# Maintainer: Framebolt contributors
pkgname=framebolt-bin
pkgver=${RELEASE_VERSION}
pkgrel=1
pkgdesc='Framebolt (prebuilt binary)'
arch=('x86_64')
url='https://github.com/${REPO}'
license=('MIT')
provides=('framebolt')
conflicts=('framebolt' 'framebolt-git')
source=("${BINARY_NAME}::${BINARY_URL}")
sha256sums=('SKIP')

package() {
    # Handle the common case where the release asset is a directly
    # executable binary.
    if file "\${srcdir}/${BINARY_NAME}" | grep -qi 'executable'; then
        install -Dm755 \
            "\${srcdir}/${BINARY_NAME}" \
            "\${pkgdir}/usr/bin/framebolt"
        return
    fi

    # Otherwise unpack an archive and locate the executable.
    local extract_dir="\${srcdir}/extract"
    mkdir -p "\${extract_dir}"

    case "${BINARY_NAME}" in
        *.tar.gz|*.tgz)
            tar -xzf "\${srcdir}/${BINARY_NAME}" -C "\${extract_dir}"
            ;;
        *.tar.xz)
            tar -xJf "\${srcdir}/${BINARY_NAME}" -C "\${extract_dir}"
            ;;
        *.tar.zst)
            tar --zstd -xf "\${srcdir}/${BINARY_NAME}" -C "\${extract_dir}"
            ;;
        *.zip)
            bsdtar -xf "\${srcdir}/${BINARY_NAME}" -C "\${extract_dir}"
            ;;
        *.AppImage|*.appimage)
            install -Dm755 \
                "\${srcdir}/${BINARY_NAME}" \
                "\${pkgdir}/usr/bin/framebolt"
            return
            ;;
        *)
            echo "error: unsupported release asset: ${BINARY_NAME}" >&2
            return 1
            ;;
    esac

    local binary
    binary="\$(find "\${extract_dir}" -type f -name framebolt -print -quit)"

    if [[ -z "\${binary}" ]]; then
        binary="\$(find "\${extract_dir}" -type f -perm -u+x -print -quit)"
    fi

    if [[ -z "\${binary}" ]]; then
        echo "error: could not find framebolt executable in release archive" >&2
        find "\${extract_dir}" -maxdepth 3 -type f -print >&2
        return 1
    fi

    install -Dm755 "\${binary}" "\${pkgdir}/usr/bin/framebolt"
}
EOF

###############################################################################
# framebolt-git
#
# Latest commit from main.
###############################################################################

FRAMEBOLT_GIT_DIR="${OUT_DIR}/framebolt-git"

write_common_metadata "$FRAMEBOLT_GIT_DIR" framebolt-git "r$(date +%Y%m%d)"

cat > "$FRAMEBOLT_GIT_DIR/PKGBUILD" <<EOF
# Maintainer: Framebolt contributors
pkgname=framebolt-git
pkgver=r1.g${MAIN_SHA:0:7}
pkgrel=1
pkgdesc='Framebolt (latest main branch)'
arch=('x86_64')
url='https://github.com/${REPO}'
license=('MIT')
depends=()
makedepends=('git' 'rust')
provides=('framebolt')
conflicts=('framebolt' 'framebolt-bin')
source=('git+https://github.com/${REPO}.git#branch=${MAIN_BRANCH}')
sha256sums=('SKIP')

pkgver() {
    cd "\${srcdir}/framebolt"

    printf 'r%s.g%s\\n' \
        "\$(git rev-list --count HEAD)" \
        "\$(git rev-parse --short HEAD)"
}

build() {
    cd "\${srcdir}/framebolt"

    cargo build --release --locked
}

package() {
    cd "\${srcdir}/framebolt"

    install -Dm755 "target/release/framebolt" \
        "\${pkgdir}/usr/bin/framebolt"

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
echo "Main:    ${MAIN_SHA}"
echo "Binary:  ${BINARY_NAME}"
```
