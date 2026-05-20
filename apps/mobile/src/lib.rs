use eframe::egui;
use framebolt_egui::{app::SharedApp, renderer::{prepare_renderer_then}, viewport::canvas_viewport};
pub struct FrameboltMobileApp {
    shared: SharedApp,
}

impl FrameboltMobileApp {
    pub fn new() -> Self {
        Self { shared: SharedApp::default() }
    }
}

impl eframe::App for FrameboltMobileApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        prepare_renderer_then(ctx, frame, &mut self.shared.renderer, |queue, renderer| {
                egui::CentralPanel::default().show(ctx, |ui| {
                    canvas_viewport(
                        ui,
                        renderer,
                        Some(queue),
                    );
                });
            },
        );
    }
}

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
fn android_main(app: winit::platform::android::activity::AndroidApp) {
    let options = eframe::NativeOptions {
        android_app: Some(app),
        ..Default::default()
    };
    let _ = framebolt_egui::app::run_app(
        options,
        |_cc| FrameboltMobileApp::new(),
    );
}