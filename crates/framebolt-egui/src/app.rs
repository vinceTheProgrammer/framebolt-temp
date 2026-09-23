use eframe::egui;

use crate::renderer::SharedRenderer;

#[derive(Default)]
pub struct SharedApp {
    pub renderer: Option<SharedRenderer>,
}

pub fn run_app<A>(
    options: eframe::NativeOptions,
    create: impl FnOnce(&eframe::CreationContext<'_>) -> A + 'static,
) -> Result<(), eframe::Error>
where
    A: eframe::App + 'static,
{
    eframe::run_native(
        "framebolt",
        options,
        Box::new(move |cc| {
            let mut fonts = egui::FontDefinitions::default();
            egui_phosphor::add_to_fonts(&mut fonts, egui_phosphor::Variant::Regular);

            cc.egui_ctx.set_fonts(fonts);
            
            Ok(Box::new(create(cc)))
            }
        ),
    )
}