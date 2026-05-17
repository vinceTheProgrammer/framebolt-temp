use gstreamer as gst;

pub fn gstreamer_report() -> String {
    let mut report = String::new();
    
    gst::init().expect("Failed to init GStreamer");

    let version = gst::version();

    report.push_str(&format!(
        "GStreamer runtime: {}.{}.{}\n",
        version.0, version.1, version.2
    ));

    let version_str = gst::version_string();

    report.push_str(&format!(
        "GStreamer full version: {}\n",
        version_str
    ));

    report
}