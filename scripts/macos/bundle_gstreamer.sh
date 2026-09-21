#!/bin/bash
set -euo pipefail

echo "=== Starting GStreamer bundling process ==="

APP_PATH="target/release/framebolt.app"
GST_PREFIX="/Library/Frameworks/GStreamer.framework/Versions/Current"
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
PLUGIN_SRC="$GST_PREFIX/lib/gstreamer-1.0"
PLUGIN_DEST="$APP_PATH/Contents/Resources/lib/gstreamer-1.0"
APP_BIN="$APP_PATH/Contents/MacOS/framebolt"

mkdir -p "$FRAMEWORKS_DIR" "$PLUGIN_DEST"

COPIED_LIBS_FILE="$(mktemp)"

has_copied() { grep -Fxq "$1" "$COPIED_LIBS_FILE" 2>/dev/null; }
mark_copied() { echo "$1" >> "$COPIED_LIBS_FILE"; }

# --- Resolve @rpath entries to actual files in $GST_PREFIX/lib ---
resolve_dylib_path() {
  dep="$1"
  if [[ "$dep" == @rpath/* ]]; then
    name="${dep#@rpath/}"
    candidate="$GST_PREFIX/lib/$name"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  fi
  echo "$dep"
}

# --- Recursive copy function ---
copy_dylib_recursive() {
  dylib_path="$1"
  resolved_path=$(resolve_dylib_path "$dylib_path")

  if has_copied "$resolved_path"; then
    echo "  [skip] Already copied: $resolved_path"
    return
  fi
  mark_copied "$resolved_path"

  dylib_name=$(basename "$resolved_path")

  if [[ ! -f "$resolved_path" ]]; then
    echo "  [warn] Dylib not found on disk: $resolved_path"
    return
  fi

  echo "  [copy] $resolved_path → $FRAMEWORKS_DIR/$dylib_name"
  cp -a "$resolved_path" "$FRAMEWORKS_DIR/$dylib_name"

  echo "  [set-id] install_name_tool -id @rpath/$dylib_name"
  install_name_tool -id "@rpath/$dylib_name" "$FRAMEWORKS_DIR/$dylib_name" || true

  echo "  [deps] Inspecting dependencies of $dylib_name..."
  otool -L "$resolved_path" | awk 'NR>1 {print $1}' | while read -r dep; do
    resolved_dep=$(resolve_dylib_path "$dep")
    dep_basename=$(basename "$resolved_dep")

    if [[ "$resolved_dep" == "$GST_PREFIX/lib/"*".dylib" || "$resolved_dep" == @rpath/libgst* || "$resolved_dep" == @rpath/libgobject* || "$resolved_dep" == @rpath/libglib* ]]; then
      echo "     ↳ GStreamer dependency: $resolved_dep → relinking to @rpath/$dep_basename"
      install_name_tool -change "$dep" "@rpath/$dep_basename" "$FRAMEWORKS_DIR/$dylib_name" || true
      if [[ ! -f "$FRAMEWORKS_DIR/$dep_basename" ]]; then
        copy_dylib_recursive "$resolved_dep"
      fi
    else
      echo "     ↳ Skipping non-GStreamer dep: $dep"
    fi
  done
}

# --- Scan app binary dependencies ---
echo "🔍 Scanning app binary dependencies..."
otool -L "$APP_BIN" | awk 'NR>1 {print $1}' | while read -r dep; do
  echo "  [app-dep] $dep"
  resolved=$(resolve_dylib_path "$dep")

  if [[ "$resolved" == "$GST_PREFIX/lib/"*".dylib" || "$resolved" == @rpath/libgst* || "$resolved" == @rpath/libgobject* || "$resolved" == @rpath/libglib* ]]; then
    echo "  [match] GStreamer dylib found: $resolved"
    copy_dylib_recursive "$resolved"
    dep_basename=$(basename "$resolved")
    echo "  [relink] install_name_tool -change $dep @rpath/$dep_basename $APP_BIN"
    install_name_tool -change "$dep" "@rpath/$dep_basename" "$APP_BIN" || true
  else
    echo "  [skip] Non-GStreamer dependency: $dep"
  fi
done

echo "📦 Adding RPATH to app binary..."
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BIN" || true

echo "🧩 Copying GStreamer plugins (excluding .a and .pc)..."
rsync -av --exclude='*.a' --exclude='*.pc' "$PLUGIN_SRC/" "$PLUGIN_DEST/"

echo "🔗 Relinking plugin dependencies..."
find "$PLUGIN_DEST" -type f -perm +111 -name "*.so" | while read -r plugin; do
  echo "  [plugin] $(basename "$plugin")"
  otool -L "$plugin" | awk 'NR>1 {print $1}' | while read -r dep; do
    resolved=$(resolve_dylib_path "$dep")
    dep_basename=$(basename "$resolved")
    if [[ "$resolved" == "$GST_PREFIX/lib/"*".dylib" || "$resolved" == @rpath/libgst* || "$resolved" == @rpath/libgobject* || "$resolved" == @rpath/libglib* ]]; then
      echo "    ↳ Relinking $dep → @rpath/$dep_basename"
      install_name_tool -change "$dep" "@rpath/$dep_basename" "$plugin" || true
      if [[ ! -f "$FRAMEWORKS_DIR/$dep_basename" ]]; then
        copy_dylib_recursive "$resolved"
      fi
    fi
  done
done

COPIED_COUNT=$(wc -l < "$COPIED_LIBS_FILE")
rm -f "$COPIED_LIBS_FILE"

echo "✅ Done!"
echo "   → Copied $COPIED_COUNT GStreamer dylibs to $FRAMEWORKS_DIR"
echo "   → Plugins copied and relinked successfully"
echo "=== GStreamer bundling process complete ==="