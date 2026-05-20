use crate::renderer::SharedRenderer;

pub struct SharedApp {
    pub renderer: Option<SharedRenderer>,
}

impl Default for SharedApp {
    fn default() -> Self {
        Self {
            renderer: None,
        }
    }
}

pub fn run_app<A>(
    options: eframe::NativeOptions,
    create: impl FnOnce(&eframe::CreationContext<'_>) -> A + 'static,
) -> Result<(), eframe::Error>
where
    A: eframe::App + 'static,
{
    eframe::run_native(
        "Framebolt",
        options,
        Box::new(move |cc| Ok(Box::new(create(cc)))),
    )
}