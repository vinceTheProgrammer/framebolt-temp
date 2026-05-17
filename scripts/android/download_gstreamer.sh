#!/usr/bin/env bash
set -e

GST_DEV_URL="https://github.com/vinceTheProgrammer/gstreamer-android-universal-dynamic-build/releases/download/v1.27.2.1/gstreamer-1.0-android-universal-1.27.2.1.tar.xz"
GST_RUNTIME_URL="https://github.com/vinceTheProgrammer/gstreamer-android-universal-dynamic-build/releases/download/v1.27.2.1/gstreamer-1.0-android-universal-1.27.2.1-runtime.tar.xz"

echo "Downloading GStreamer Android SDK..."

curl -L "$GST_DEV_URL" -o gstreamer-android.tar.xz
mkdir -p gstreamer-android
tar -xf gstreamer-android.tar.xz -C gstreamer-android

echo "Downloading GStreamer Android Runtime..."

curl -L "$GST_RUNTIME_URL" -o gstreamer-android-runtime.tar.xz
mkdir -p gstreamer-android-runtime
tar -xf gstreamer-android-runtime.tar.xz -C gstreamer-android-runtime