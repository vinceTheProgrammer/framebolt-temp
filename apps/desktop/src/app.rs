use eframe::wgpu::Queue;
use egui_dock::{DockArea, DockState};
use framebolt_egui::{app::SharedApp, renderer::{SharedRenderer, prepare_renderer_then}};

pub struct FrameboltDesktopApp {
    dock_state: DockState<Tab>,
    shared: SharedApp,
}

#[derive(Clone)]
pub enum Tab {
    Tools,
    Timeline,
    Canvas,
}

impl FrameboltDesktopApp {
    pub fn new(_cc: &eframe::CreationContext<'_>) -> Self {
        let mut dock_state = DockState::new(vec![Tab::Canvas]);

        dock_state
            .main_surface_mut()
            .split_left(
                egui_dock::NodeIndex::root(),
                0.1,
                vec![Tab::Tools, Tab::Timeline],
            );

        Self {
            dock_state,
            shared: SharedApp::default(),
        }
    }
}

impl eframe::App for FrameboltDesktopApp {
    fn update(&mut self, ctx: &eframe::egui::Context, frame: &mut eframe::Frame) {

        prepare_renderer_then(
            ctx,
            frame,
            &mut self.shared.renderer,
            |queue, renderer| {
                DockArea::new(&mut self.dock_state)
                    .show(ctx, &mut TabViewer {
                        renderer,
                        queue: Some(queue),
                    });
            },
        );
        
    }
}

struct TabViewer<'a> {
    renderer: SharedRenderer,
    queue: Option<&'a Queue>,
}

impl<'a> egui_dock::TabViewer for TabViewer<'a> {
    type Tab = Tab;

    fn ui(&mut self, ui: &mut eframe::egui::Ui, tab: &mut Tab) {
        match tab {
            Tab::Canvas => {
                framebolt_egui::viewport::canvas_viewport(
                    ui,
                    self.renderer.clone(),
                    self.queue.clone(),
                );
            }

            Tab::Tools => {
                ui.heading("Tools");
            }

            Tab::Timeline => {
                ui.heading("Timeline");
            }
        }
    }

    fn title(&mut self, tab: &mut Tab) -> eframe::egui::WidgetText {
        match tab {
            Tab::Canvas => "Canvas".into(),
            Tab::Tools => "Tools".into(),
            Tab::Timeline => "Timeline".into(),
        }
    }
}