#!/usr/bin/env bash
set -euo pipefail

# ---- Runtime ----
cd gstreamer-android-runtime

# for abi in armeabi-v7a arm64-v8a x86 x86_64; do
for abi in armv7 arm64 x86 x86_64; do
  SRC="./${abi}/lib"
  BASE="../res/android/libs"
  DST="${BASE}/${abi}"

  mkdir -p "$DST"

  echo "Copying $abi libs"

  cp $SRC/*.so "$DST/"
  find $SRC/gstreamer-1.0 -name "*.so" -exec cp {} "$DST/" \;
  find $SRC/gio/modules -name "*.so" -exec cp {} "$DST/" \;
done

mv ${BASE}/armv7 ${BASE}/armeabi-v7a
mv ${BASE}/arm64 ${BASE}/arm64-v8a

echo "✅ GStreamer runtime staged"

# ---- Headers ----
cd ../gstreamer-android

# mv armv7 armeabi-v7a || true
# mv arm64 arm64-v8a || true

HEADERS_DST="../res/android/gstreamer"
HEADERS_SRC="./arm64"

echo "Copying include headers..."
mkdir -p "$HEADERS_DST/include"
mkdir -p "$HEADERS_DST/lib/glib-2.0/include"

cp -r -v $HEADERS_SRC/include/* $HEADERS_DST/include/
cp -r -v $HEADERS_SRC/lib/glib-2.0/include/* $HEADERS_DST/lib/glib-2.0/include/