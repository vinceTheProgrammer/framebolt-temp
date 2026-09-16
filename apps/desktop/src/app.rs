use eframe::{egui, wgpu::Queue};
use egui_dock::{DockArea, DockState};
use framebolt_egui::{app::SharedApp, panels::{PanelContext, PanelId, PanelLocation, PanelRegistry, Platform, canvas::CanvasPanel, timeline::TimelinePanel, tools::ToolsPanel}, renderer::{SharedRenderer, prepare_renderer_then}};

pub struct FrameboltDesktopApp {
    dock_state: DockState<DockTab>,
    shared: SharedApp,
    panels: PanelRegistry,
}

#[derive(Clone)]
pub struct DockTab {
    pub panel: PanelId,
}

impl FrameboltDesktopApp {
    pub fn new(_cc: &eframe::CreationContext<'_>) -> Self {
        let mut dock_state = DockState::new(vec![
            DockTab {
                panel: PanelId::Canvas,
            }
        ]);

        dock_state
            .main_surface_mut()
            .split_below(
                egui_dock::NodeIndex::root(),
                0.8,
                vec![
                    DockTab {
                        panel: PanelId::Timeline,
                    },
                ],
            );

        dock_state
            .main_surface_mut()
            .split_left(
                egui_dock::NodeIndex::root(),
                0.2,
                vec![
                    DockTab {
                        panel: PanelId::Tools,
                    },
                ],
            );


        let mut panels = PanelRegistry::new();

        panels.register(Box::new(
            ToolsPanel::default()
        ));

        panels.register(Box::new(
            TimelinePanel::default()
        ));

        panels.register(Box::new(
            CanvasPanel::default()
        ));

        Self {
            dock_state,
            shared: SharedApp::default(),
            panels,
        }
    }
}

impl eframe::App for FrameboltDesktopApp {
    fn update(&mut self, ctx: &eframe::egui::Context, frame: &mut eframe::Frame) {

        prepare_renderer_then(
            ctx,
            frame,
            &mut self.shared,
            |queue, shared| {
                DockArea::new(&mut self.dock_state)
                    .show(ctx, &mut TabViewer {
                        shared,
                        queue,
                        panels: &mut self.panels,
                    });
            },
        );
        
    }
}

struct TabViewer<'a> {
    shared: &'a mut SharedApp,
    queue: &'a Queue,
    panels: &'a mut PanelRegistry,
}

impl<'a> egui_dock::TabViewer for TabViewer<'a> {
    type Tab = DockTab;

    fn ui(
        &mut self,
        ui: &mut egui::Ui,
        tab: &mut DockTab,
    ) {
        if let Some(panel) =
            self.panels.panel_mut(tab.panel)
        {
            let mut ctx = PanelContext {
                platform: Platform::Desktop,
                shared: self.shared,
                panel_location: PanelLocation::Docked, // todo set to docked/floating dynamically
                queue: Some(self.queue),
            };

            panel.ui(ui, &mut ctx);
        }
    }

    fn title(
        &mut self,
        tab: &mut DockTab,
    ) -> egui::WidgetText {
        if let Some(panel) =
            self.panels.panel_mut(tab.panel)
        {
            panel.title().into()
        } else {
            "Unknown".into()
        }
    }
}