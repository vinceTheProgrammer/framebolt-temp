pub mod app;
pub mod desktop;
pub mod mobile;

pub use app::FrameboltApp;

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub fn android_main(
    app: winit::platform::android::activity::AndroidApp,
) {
    let options = eframe::NativeOptions {
        android_app: Some(app),
        ..Default::default()
    };

    let _ = framebolt_egui::app::run_app(
        options,
        |_cc| crate::FrameboltApp::new(),
    );
}