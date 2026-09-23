use eframe::egui::{self, ahash::{HashMap, HashMapExt}};

use crate::app::SharedApp;

pub mod timeline;
pub mod tools;
pub mod canvas;

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub enum PanelId {
    Timeline,
    Tools,
    Canvas,
}

#[derive(Clone, Copy)]
pub enum Platform {
    Desktop,
    Mobile,
}

pub enum PanelLocation {
    Left,
    Right,
    Top,
    Bottom,
    Center,
    Docked,
    Floating,
}

pub struct PanelContext<'a> {
    pub platform: Platform,
    pub panel_location: PanelLocation,
    pub shared: &'a mut SharedApp,
    pub queue: Option<&'a wgpu::Queue>,
}

pub trait Panel {
    fn id(&self) -> PanelId;

    fn title(&self) -> &'static str;

    fn ui(
        &mut self,
        ui: &mut egui::Ui,
        ctx: &mut PanelContext,
    );
}

pub struct PanelRegistry {
    panels: HashMap<PanelId, Box<dyn Panel>>,
}

impl Default for PanelRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl PanelRegistry {
    pub fn new() -> Self {
        Self {
            panels: HashMap::new(),
        }
    }

    pub fn register(
        &mut self,
        panel: Box<dyn Panel>,
    ) {
        let id = panel.id();
        self.panels.insert(id, panel);
    }

    pub fn panel_mut(
        &mut self,
        id: PanelId,
    ) -> Option<&mut Box<dyn Panel>> {
        self.panels.get_mut(&id)
    }
}