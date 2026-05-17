pub mod app;

fn main() -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions {
        renderer: eframe::Renderer::Wgpu,
        ..Default::default()
    };
    
    eframe::run_native(
        "Framebolt",
        options,
        Box::new(|cc| Ok(Box::new(app::FrameboltApp::new(cc)))),
    )
}