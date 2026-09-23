use std::{env, path::PathBuf};

fn main() {
    let target = env::var("TARGET").unwrap();

    if target.contains("android") {
        let abi = if target.contains("aarch64") {
            "arm64-v8a"
        } else if target.contains("armv7") {
            "armeabi-v7a"
        } else if target.contains("x86_64") {
            "x86_64"
        } else {
            "x86"
        };

        // Workspace root (framebolt/)
        let workspace_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap())
            .parent()
            .unwrap()
            .parent()
            .unwrap()
            .to_path_buf();

        let lib_dir = workspace_root.join("res/android/libs").join(abi);

        println!("cargo:rustc-link-search=native={}", lib_dir.display());

        println!("cargo:rustc-link-lib=dylib=gstreamer-1.0");
        println!("cargo:rustc-link-lib=dylib=gstbase-1.0");
        println!("cargo:rustc-link-lib=dylib=gobject-2.0");
        println!("cargo:rustc-link-lib=dylib=glib-2.0");
    }
}
