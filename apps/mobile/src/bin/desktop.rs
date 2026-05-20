use framebolt_mobile::FrameboltMobileApp;

fn main() {
    let options = eframe::NativeOptions {
        renderer: eframe::Renderer::Wgpu,
        ..Default::default()
    };
    let _ = framebolt_egui::app::run_app(
        options,
        |_cc| FrameboltMobileApp::new(),
    );
}