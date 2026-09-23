2D Animation Plugin Platform*

*The "plugin platform" part is still wip lol

ALL INSTRUCTIONS BELOW ASSUME RUST IS INSTALLED (e.g. usage of the `cargo` command requires Rust)

All instructions below assume your current directory is the root of the project.

# Desktop
## Quickstart
### Run (debug)
```
cargo run
```
*Add `--release` to run the release version*

### Build (debug)
```
cargo build
```
*Add `--release` to run the release version*

## Linux
### AppImage
#### Prerequisites
1. Ensure `linuxdeploy` is installed
#### Build
```
cargo build --release
./scripts/linux/package_appimage.sh
```

### .deb
#### Prerequisites
1. Ensure `python3` is installed
2. Ensure `dpkg-deb` is installed
#### Build
```
cargo build --release
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
1. Ensure gstreamer is installed and on youor `PATH`
2. Ensure Java is installed and on your `PATH` (not sure what minimum version tbh)
3. Ensure Android SDK is installed and `ANDROID_HOME` environment variable points to its root
4. Ensure the following Android SDK components are installed to your Android SDK root:
- Latest `platform-tools`
- Latest `build-tools`
- `platforms;android-34`
- `ndk;25.2.9519653` and set `NDK_HOME` to point to it (usually a subfolder of the Android SDK root)
5. Install cargo-apk2 globally (handles building the app for Android)
```
cargo install cargo-apk2
```
6. Download the prebuilt Android compatible gstreamer libs
```
./scripts/android/download_gstreamer.sh
```
7. Stage the gstreamer libs to the correct file structure for the build
```
./scripts/android/stage_gstreamer.sh
```

### Build (debug)
Specify what architectures the apk will support by setting `package.metadata.android.build_targets` in `Cargo.toml` accordingly. Every included target will be included in the built apk.
```
# Specifies the array of targets to build for.
build_targets = [ 
    # "armv7-linux-androideabi", 
    "aarch64-linux-android", 
    # "i686-linux-android", 
    # "x86_64-linux-android" 
]
```
```
./scripts/android/build_debug.sh
```

### Run (debug)
1. Connect Android device via adb
2. 
```
./scripts/android/run.sh
```

### Build (release)
```
./scripts/android/build.sh
```

## iOS
Not yet supported




# Draft explanation of project structure:

- `.cargo/config.toml` - don't remember for sure, but I think I may have at one poiont determined that it was needed to build for Android, at least on my system. Maybe it's not needed for CI. I should probably test that at some point.

- `.github/workflows/build.yml` - the FATASS of a github action that builds Framebolt for every platform under the sun

- `assets` - holds things that should be packaged inside of the app

- `crates` - subprojects of Framebolt to make it easier to reason about things

- `crates/framebolt-canvas` - the heart of Framebolt. Handles everything related to rendering graphics to the canvas

- `crates/framebolt-core` - the brain of Framebolt. Holds all essential core state and functionality

- `crates/framebolt-egui` - the face of Framebolt. Holds all gui related code

- `crates/framebolt-gstreamer` - interface between `crates/media` and gstreamer

- `crates/framebolt-media` - takes media related queries and talks with other tools to make it happen. e.g. framebolt-core may request from `crates/media` that a video be rendered, and then `crates/media` will ask gstreamer to render it. This layer between gstreamer and the rest of framebolt could useful for if I ever need to switch out gstreamer or add other media related libraries

- `crates/framebolt-plugin-api` - defines a plugin api for Framebolt plugins to interface with

- `crates/framebolt-plugins` - default plugins to be baked into the app (e.g. basic drawing tools)

- `res` - resources needed when building Framebolt

- `scripts` - scripts to make building Framebolt easier (tested mostly for ci, but in theory most should work locally too)

- `src` - framebolt entry point code. for each platform, initialize eframe, egui, core, etc.