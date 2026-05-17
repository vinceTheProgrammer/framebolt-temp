fn main() {
    let options = eframe::NativeOptions {
        renderer: eframe::Renderer::Wgpu,
        ..Default::default()
    };
    let _ = framebolt_mobile::run(options);
}