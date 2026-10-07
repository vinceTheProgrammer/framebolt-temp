#[cfg(target_os = "android")]
use framebolt::{FrameboltApp, platform_adapters::eframe::FrameboltEframeAdapter};

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub fn android_main(app: winit::platform::android::activity::AndroidApp) -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions {
        android_app: Some(app),
        ..Default::default()
    };

    let framebolt_app = FrameboltApp::new();

    eframe::run_native(
        "Framebolt",
        options,
        Box::new(|cc| {
            framebolt_app.configure_egui(&cc.egui_ctx);

            Ok(Box::new(FrameboltEframeAdapter {
                app: framebolt_app,
            }))
        }),
    )
}