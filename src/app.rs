use eframe::egui;

use egui_dock::DockState;
use framebolt_egui::{
    app::SharedApp,
    panels::{
        PanelRegistry,
        canvas::CanvasPanel,
        timeline::TimelinePanel,
        tools::ToolsPanel,
    },
    renderer::prepare_renderer_then,
};

use crate::{
    desktop::{self, DockTab, create_dock_state}, mobile::{self, ShownPanels},
};


pub enum UiMode {
    Desktop,
    Mobile,
}

pub struct FrameboltApp {
    shared: SharedApp,
    panels: PanelRegistry,
    ui_mode: UiMode,

    // Desktop-specific state
    dock_state: DockState<DockTab>,

    pub shown_panels: ShownPanels,
}

impl Default for FrameboltApp {
    fn default() -> Self {
        Self::new()
    }
}

impl FrameboltApp {
    pub fn new() -> Self {
        let ui_mode = if cfg!(any(target_os = "android", target_os = "ios")) {
            UiMode::Mobile
        } else {
            UiMode::Desktop
        };

        Self {
            shared: SharedApp::default(),
            panels: create_panels(),
            ui_mode,
            dock_state: create_dock_state(),

            shown_panels: ShownPanels {
                top: false,
                bottom: true,
                left: true,
                right: false,
            }
        }
    }

    pub fn set_ui_mode(&mut self, mode: UiMode) {
        self.ui_mode = mode;
    }
}

impl eframe::App for FrameboltApp {
    fn update(
        &mut self,
        ctx: &egui::Context,
        frame: &mut eframe::Frame,
    ) {
        prepare_renderer_then(
            ctx,
            frame,
            &mut self.shared,
            |queue, shared| {
                match self.ui_mode {
                    UiMode::Desktop => {
                        desktop::show(ctx, queue, shared, &mut self.panels, &mut self.dock_state);
                    }

                    UiMode::Mobile => {
                        mobile::show(ctx, queue, shared, &mut self.panels, self.shown_panels);
                    }
                }
            },
        );
    }
}

fn create_panels() -> PanelRegistry {
    let mut panels = PanelRegistry::new();

    panels.register(Box::new(ToolsPanel::default()));
    panels.register(Box::new(TimelinePanel::default()));
    panels.register(Box::new(CanvasPanel::default()));

    panels
}