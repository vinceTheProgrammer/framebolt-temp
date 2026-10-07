use framebolt::{FrameboltApp, platform_adapters::eframe::FrameboltEframeAdapter};

fn main() -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions {
        renderer: eframe::Renderer::Wgpu,
        ..Default::default()
    };

    let app = FrameboltApp::new();

    eframe::run_native(
        "Framebolt",
        options,
        Box::new(|cc| {
            app.configure_egui(&cc.egui_ctx);

            Ok(Box::new(FrameboltEframeAdapter {
                app,
            }))
        }),
    )
}
