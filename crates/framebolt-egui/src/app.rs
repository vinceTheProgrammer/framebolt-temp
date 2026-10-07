use crate::renderer::SharedRenderer;

#[derive(Default)]
pub struct SharedApp {
    pub renderer: Option<SharedRenderer>,
}

impl SharedApp {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn configure_egui(ctx: &egui::Context) {
        let mut fonts = egui::FontDefinitions::default();

        egui_phosphor::add_to_fonts(
            &mut fonts,
            egui_phosphor::Variant::Regular,
        );

        ctx.set_fonts(fonts);
    }
}
