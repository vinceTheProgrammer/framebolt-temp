#!/usr/bin/env bash
set -e

export ANDROID_HOME=/opt/android-sdk
export NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653
export ANDROID_NDK=$NDK_HOME

GST_ROOT=$(pwd)/gstreamer-android

export PKG_CONFIG_ALLOW_CROSS=1

# Tell Rust where the GStreamer pkgconfig files live
export PKG_CONFIG_PATH="$GST_ROOT/arm64/lib/pkgconfig"

# Rust Android toolchains
export CC_aarch64_linux_android=$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android23-clang
export AR_aarch64_linux_android=$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar

export CC_armv7_linux_androideabi=$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi23-clang
export AR_armv7_linux_androideabi=$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar

cd apps/mobile

rustup target add armv7-linux-androideabi
rustup target add aarch64-linux-android
rustup target add i686-linux-android
rustup target add x86_64-linux-android

cargo apk2 build --release --lib