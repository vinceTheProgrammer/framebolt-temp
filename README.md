2D Animation Plugin Platform*

*The "plugin platform" part is still wip lol

ALL INSTRUCTIONS BELOW ASSUME RUST IS INSTALLED (e.g. usage of the `cargo` command requires Rust)

All instructions below assume your current directory is the root of the project.

# Desktop
## Quickstart
### Run (debug)
```
cargo run -p framebolt-desktop
```
*Add `--release` to run the release version*

### Build (debug)
```
cargo build -p framebolt-desktop
```
*Add `--release` to run the release version*

## Linux
### AppImage
#### Prerequisites
1. Ensure `linuxdeploy` is installed
#### Build
```
cargo build -p framebolt-desktop --release
./scripts/linux/package_appimage.sh
```

### .deb
#### Prerequisites
1. Ensure `python3` is installed
2. Ensure `dpkg-deb` is installed
#### Build
```
cargo build -p framebolt-desktop --release
./scripts/linux/package_deb.sh
```
useful for testing:
```
podman run --rm -it \
    --platform linux/amd64 \
    -v "$PWD:/pkg" \
    ubuntu:24.04 \
    bash
```
then for a quick sanity check of the `.deb` using the ubuntu container you just entered:
```
apt update
apt install -y /pkg/framebolt_0.1.0_amd64.deb
```


# Mobile
## Mobile UI on Desktop
### Run (debug)
```
cargo run -p framebolt-mobile
```
*Add `--release` to run the release version*
### Build (debug)
```
cargo build -p framebolt-mobile
```
*Add `--release` to run the release version*

## Android
### Prerequisites
1. Ensure Java is installed and on your `PATH` (not sure what minimum version tbh)
2. Ensure Android SDK is installed and `ANDROID_HOME` environment variable points to its root
3. Ensure the following Android SDK components are installed to your Android SDK root:
- Latest `platform-tools`
- Latest `build-tools`
- `platforms;android-34`
- `ndk;25.2.9519653` and set `NDK_HOME` to point to it (usually a subfolder of the Android SDK root)
4. Install cargo-apk2 globally (handles building the app for Android)
```
cargo install cargo-apk2
```
5. Download the prebuilt Android compatible gstreamer libs
```
./scripts/android/download_gstreamer.sh
```
6. Stage the gstreamer libs to the correct file structure for the build
```
./scripts/android/stage_gstreamer.sh
```

### Run (debug)
1. Connect Android device via adb
2. 
```
./scripts/android/run.sh
```

### Build (debug)
```
./scripts/android/build_debug.sh
```
### Build (release)
```
./scripts/android/build.sh
```

## iOS
Not yet supported