use framebolt_gstreamer::gstreamer_report;

pub fn dependency_report() -> String {
    let mut report = String::new();

    report.push_str("Framebolt dependency report\n\n");

    // Rust version
    report.push_str(&format!(
        "Rustc: {}\n",
        rustc_version_runtime::version()
    ));

    report.push_str(&gstreamer_report());

    // wasmtime
    report.push_str(&format!(
        "wasmtime: {:?}\n",
        wasmtime::WasmFeatures::all()
    ));

    report
}