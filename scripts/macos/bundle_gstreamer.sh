#!/bin/bash
set -euo pipefail

echo "=== Starting GStreamer bundling process ==="

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

APP_PATH="${APP_PATH:-target/release/framebolt-desktop.app}"
APP_BIN="$APP_PATH/Contents/MacOS/framebolt-desktop"

if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: App bundle not found: $APP_PATH"
    exit 1
fi

if [[ ! -f "$APP_BIN" ]]; then
    echo "ERROR: App binary not found: $APP_BIN"
    exit 1
fi

# Ask Homebrew for the actual GStreamer installation prefix.
#
# This avoids hard-coding paths such as:
#   /opt/homebrew/Cellar/gstreamer/1.28.6_3
#
# and also works when Homebrew updates GStreamer.
if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew was not found."
    exit 1
fi

GST_PREFIX="$(brew --prefix gstreamer)"

FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
PLUGIN_SRC="$GST_PREFIX/lib/gstreamer-1.0"
PLUGIN_DEST="$APP_PATH/Contents/Resources/lib/gstreamer-1.0"

echo "App:              $APP_PATH"
echo "App binary:       $APP_BIN"
echo "GStreamer prefix: $GST_PREFIX"
echo "GStreamer libs:   $GST_PREFIX/lib"
echo "GStreamer plugins:$PLUGIN_SRC"

# ---------------------------------------------------------------------------
# Validate GStreamer installation
# ---------------------------------------------------------------------------

if [[ ! -d "$GST_PREFIX" ]]; then
    echo "ERROR: GStreamer prefix does not exist: $GST_PREFIX"
    exit 1
fi

if [[ ! -d "$GST_PREFIX/lib" ]]; then
    echo "ERROR: GStreamer lib directory not found: $GST_PREFIX/lib"
    exit 1
fi

if [[ ! -d "$PLUGIN_SRC" ]]; then
    echo "ERROR: GStreamer plugin directory not found: $PLUGIN_SRC"
    exit 1
fi

mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$PLUGIN_DEST"

# ---------------------------------------------------------------------------
# Dependency tracking
# ---------------------------------------------------------------------------

COPIED_LIBS_FILE="$(mktemp)"

cleanup() {
    rm -f "$COPIED_LIBS_FILE"
}

trap cleanup EXIT

canonical_path() {
    local path="$1"

    if [[ -e "$path" ]]; then
        realpath "$path"
    else
        echo "$path"
    fi
}

has_copied() {
    local path="$1"
    local canonical

    canonical="$(canonical_path "$path")"

    grep -Fxq "$canonical" "$COPIED_LIBS_FILE" 2>/dev/null
}

mark_copied() {
    local path="$1"
    local canonical

    canonical="$(canonical_path "$path")"

    echo "$canonical" >> "$COPIED_LIBS_FILE"
}

# ---------------------------------------------------------------------------
# Copy a dylib and recursively bundle its Homebrew dependencies
# ---------------------------------------------------------------------------

copy_dylib_recursive() {
    local dylib_path="$1"

    local resolved_path
    resolved_path="$(resolve_dylib_path "$dylib_path")"

    if [[ ! -f "$resolved_path" ]]; then
        echo "  [warn] Dylib not found on disk: $resolved_path"
        return
    fi

    # Normalize Homebrew opt/Cellar symlinks so the same library isn't
    # processed twice through different paths.
    local canonical_path_value
    canonical_path_value="$(canonical_path "$resolved_path")"

    if has_copied "$canonical_path_value"; then
        echo "  [skip] Already copied: $resolved_path"
        return
    fi

    mark_copied "$canonical_path_value"

    local dylib_name
    dylib_name="$(basename "$resolved_path")"

    local destination
    destination="$FRAMEWORKS_DIR/$dylib_name"

    # The destination may already exist because another dependency reached
    # the same dylib through a different Homebrew path.
    if [[ -f "$destination" ]]; then
        echo "  [skip] Already present: $destination"
        return
    fi

    echo "  [copy] $resolved_path"
    echo "       -> $destination"

    cp -a "$resolved_path" "$destination"

    echo "  [set-id] @rpath/$dylib_name"

    install_name_tool \
        -id "@rpath/$dylib_name" \
        "$destination" || true

    echo "  [deps] Inspecting $dylib_name..."

    otool -L "$resolved_path" |
        awk 'NR > 1 {print $1}' |
        while read -r dep; do

            [[ -z "$dep" ]] && continue

            resolved_dep="$(resolve_dylib_path "$dep")"

            if is_bundled_dependency "$resolved_dep"; then
                dep_basename="$(basename "$resolved_dep")"

                echo "     ↳ Bundling: $dep"
                echo "        -> @rpath/$dep_basename"

                install_name_tool \
                    -change "$dep" \
                    "@rpath/$dep_basename" \
                    "$destination" || true

                if [[ ! -f "$FRAMEWORKS_DIR/$dep_basename" ]]; then
                    copy_dylib_recursive "$resolved_dep"
                fi
            else
                echo "     ↳ System dependency: $dep"
            fi
        done
}

# ---------------------------------------------------------------------------
# Resolve Homebrew library paths
# ---------------------------------------------------------------------------

resolve_dylib_path() {
    local dep="$1"
    local candidate

    if [[ "$dep" == @rpath/* ]]; then
        local name="${dep#@rpath/}"

        if [[ -f "$GST_PREFIX/lib/$name" ]]; then
            realpath "$GST_PREFIX/lib/$name"
            return
        fi

        candidate="$(
            find "$(brew --prefix)" \
                -path "*/lib/$name" \
                -type f \
                2>/dev/null |
                head -n 1 || true
        )"

        if [[ -n "$candidate" && -f "$candidate" ]]; then
            realpath "$candidate"
            return
        fi
    fi

    if [[ "$dep" == /* && -f "$dep" ]]; then
        realpath "$dep"
        return
    fi

    if [[ "$dep" != */* ]]; then
        if [[ -f "$GST_PREFIX/lib/$dep" ]]; then
            realpath "$GST_PREFIX/lib/$dep"
            return
        fi

        candidate="$(
            find "$(brew --prefix)" \
                -path "*/lib/$dep" \
                -type f \
                2>/dev/null |
                head -n 1 || true
        )"

        if [[ -n "$candidate" && -f "$candidate" ]]; then
            realpath "$candidate"
            return
        fi
    fi

    echo "$dep"
}

# ---------------------------------------------------------------------------
# Determine whether a dependency belongs to the Homebrew GStreamer stack
# ---------------------------------------------------------------------------

is_bundled_dependency() {
    local dep="$1"
    local homebrew_prefix

    homebrew_prefix="$(brew --prefix)"

    # Anything installed directly under the GStreamer formula.
    if [[ "$dep" == "$GST_PREFIX/"* ]]; then
        return 0
    fi

    # Homebrew libraries under the global Homebrew prefix.
    if [[ "$dep" == "$homebrew_prefix/"* && "$dep" == *.dylib ]]; then
        return 0
    fi

    # Resolve @rpath references and check whether they resolve into Homebrew.
    local resolved
    resolved="$(resolve_dylib_path "$dep")"

    if [[ "$resolved" == "$homebrew_prefix/"* && "$resolved" == *.dylib ]]; then
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Copy a dylib and recursively bundle its Homebrew dependencies
# ---------------------------------------------------------------------------

copy_dylib_recursive() {
    local dylib_path="$1"

    local resolved_path
    resolved_path="$(resolve_dylib_path "$dylib_path")"

    if [[ ! -f "$resolved_path" ]]; then
        echo "  [warn] Dylib not found on disk: $resolved_path"
        return
    fi

    if has_copied "$resolved_path"; then
        echo "  [skip] Already copied: $resolved_path"
        return
    fi

    mark_copied "$resolved_path"

    local dylib_name
    dylib_name="$(basename "$resolved_path")"

    echo "  [copy] $resolved_path"
    echo "       -> $FRAMEWORKS_DIR/$dylib_name"

    cp -a "$resolved_path" "$FRAMEWORKS_DIR/$dylib_name"

    echo "  [set-id] @rpath/$dylib_name"

    install_name_tool \
        -id "@rpath/$dylib_name" \
        "$FRAMEWORKS_DIR/$dylib_name" || true

    echo "  [deps] Inspecting $dylib_name..."

    otool -L "$resolved_path" |
        awk 'NR > 1 {print $1}' |
        while read -r dep; do

            [[ -z "$dep" ]] && continue

            resolved_dep="$(resolve_dylib_path "$dep")"

            if is_bundled_dependency "$resolved_dep"; then
                dep_basename="$(basename "$resolved_dep")"

                echo "     ↳ Bundling: $dep"
                echo "        -> @rpath/$dep_basename"

                install_name_tool \
                    -change "$dep" \
                    "@rpath/$dep_basename" \
                    "$FRAMEWORKS_DIR/$dylib_name" || true

                if [[ ! -f "$FRAMEWORKS_DIR/$dep_basename" ]]; then
                    copy_dylib_recursive "$resolved_dep"
                fi
            else
                echo "     ↳ System dependency: $dep"
            fi
        done
}

# ---------------------------------------------------------------------------
# Scan application dependencies
# ---------------------------------------------------------------------------

echo ""
echo "=== Scanning Framebolt dependencies ==="

otool -L "$APP_BIN" |
    awk 'NR > 1 {print $1}' |
    while read -r dep; do

        [[ -z "$dep" ]] && continue

        echo "  [app-dep] $dep"

        resolved="$(resolve_dylib_path "$dep")"

        if is_bundled_dependency "$resolved"; then
            dep_basename="$(basename "$resolved")"

            echo "  [bundle] $resolved"
            echo "  [relink] $dep -> @rpath/$dep_basename"

            copy_dylib_recursive "$resolved"

            install_name_tool \
                -change "$dep" \
                "@rpath/$dep_basename" \
                "$APP_BIN" || true
        else
            echo "  [skip] $dep"
        fi
    done

# ---------------------------------------------------------------------------
# Add Frameworks directory to application RPATH
# ---------------------------------------------------------------------------

echo ""
echo "=== Configuring application RPATH ==="

install_name_tool \
    -add_rpath "@executable_path/../Frameworks" \
    "$APP_BIN" || true

# ---------------------------------------------------------------------------
# Copy GStreamer plugins
# ---------------------------------------------------------------------------

echo ""
echo "=== Copying GStreamer plugins ==="

rsync -av \
    --exclude='*.a' \
    --exclude='*.la' \
    --exclude='*.pc' \
    "$PLUGIN_SRC/" \
    "$PLUGIN_DEST/"

# ---------------------------------------------------------------------------
# Relink plugin dependencies
# ---------------------------------------------------------------------------

echo ""
echo "=== Relinking GStreamer plugin dependencies ==="

find "$PLUGIN_DEST" \
    -type f \
    -name "*.dylib" |
while read -r plugin; do

    echo "  [plugin] $(basename "$plugin")"

    otool -L "$plugin" |
        awk 'NR > 1 {print $1}' |
        while read -r dep; do

            [[ -z "$dep" ]] && continue

            resolved="$(resolve_dylib_path "$dep")"

            if is_bundled_dependency "$resolved"; then
                dep_basename="$(basename "$resolved")"

                echo "    ↳ $dep -> @rpath/$dep_basename"

                install_name_tool \
                    -change "$dep" \
                    "@rpath/$dep_basename" \
                    "$plugin" || true

                if [[ ! -f "$FRAMEWORKS_DIR/$dep_basename" ]]; then
                    copy_dylib_recursive "$resolved"
                fi
            fi
        done
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

COPIED_COUNT="$(wc -l < "$COPIED_LIBS_FILE" | tr -d ' ')"
PLUGIN_COUNT="$(find "$PLUGIN_DEST" -type f -name "*.dylib" | wc -l | tr -d ' ')"

echo ""
echo "=== GStreamer bundling complete ==="
echo "  GStreamer prefix: $GST_PREFIX"
echo "  Bundled dylibs:   $COPIED_COUNT"
echo "  Bundled plugins:  $PLUGIN_COUNT"
echo "  Frameworks:       $FRAMEWORKS_DIR"
echo "  Plugins:          $PLUGIN_DEST"
echo ""
echo "Application dependencies after bundling:"
otool -L "$APP_BIN"