use framebolt::FrameboltApp;

fn main() -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions {
        renderer: eframe::Renderer::Wgpu,
        ..Default::default()
    };

    framebolt_egui::app::run_app(
        options,
        |_cc| FrameboltApp::new(),
    )
}