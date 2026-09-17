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

// TODO don't leave this here. move it somewhere better
fn menu_item_with_shortcut(
    ui: &mut egui::Ui,
    label: &str,
    shortcut: &str,
) -> egui::Response {
    let font_id = egui::TextStyle::Button.resolve(ui.style());

    let label_width = ui
        .painter()
        .layout_no_wrap(label.to_owned(), font_id.clone(), ui.visuals().text_color())
        .size()
        .x;

    let shortcut_width = if shortcut.is_empty() {
        0.0
    } else {
        ui.painter()
            .layout_no_wrap(
                shortcut.to_owned(),
                font_id.clone(),
                ui.visuals().weak_text_color(),
            )
            .size()
            .x
    };

    let spacing = if shortcut.is_empty() { 0.0 } else { 24.0 };
    let width = ui.available_width();
    let height = ui.spacing().interact_size.y;

    let (rect, response) =
        ui.allocate_exact_size(egui::vec2(width, height), egui::Sense::click());

        if ui.is_rect_visible(rect) {
            let visuals = if response.hovered() {
                &ui.visuals().widgets.hovered
            } else {
                &ui.visuals().widgets.inactive
            };

            let bg_fill = if response.hovered() {
                visuals.bg_fill
            } else {
                egui::Color32::TRANSPARENT
            };
        
            ui.painter().rect(
                rect,
                visuals.corner_radius,
                bg_fill,
                egui::Stroke::NONE,
                egui::StrokeKind::Inside,
            );
        
            ui.painter().text(
                rect.left_center() + egui::vec2(2.0, 0.0), // TODO horrible hard coding, kill later
                egui::Align2::LEFT_CENTER,
                label,
                font_id.clone(),
                visuals.text_color(),
            );
        
            if !shortcut.is_empty() {
                ui.painter().text(
                    rect.right_center() - egui::vec2(2.0, 0.0), // TODO horrible hard coding, kill later
                    egui::Align2::RIGHT_CENTER,
                    shortcut,
                    font_id,
                    visuals.text_color().gamma_multiply(0.7),
                );
            }
        }

    response
}

fn menu_item_width(
    ui: &egui::Ui,
    label: &str,
    shortcut: &str,
) -> f32 {
    let font_id = egui::TextStyle::Button.resolve(ui.style());

    let label_width = ui
        .painter()
        .layout_no_wrap(
            label.to_owned(),
            font_id.clone(),
            ui.visuals().text_color(),
        )
        .size()
        .x;

    let shortcut_width = if shortcut.is_empty() {
        0.0
    } else {
        ui.painter()
            .layout_no_wrap(
                shortcut.to_owned(),
                font_id,
                ui.visuals().text_color(),
            )
            .size()
            .x
    };

    let spacing = if shortcut.is_empty() { 0.0 } else { 24.0 };

    4.0 + label_width + spacing + shortcut_width + 4.0
}

impl eframe::App for FrameboltDesktopApp {
    fn update(&mut self, ctx: &eframe::egui::Context, frame: &mut eframe::Frame) {

        prepare_renderer_then(
            ctx,
            frame,
            &mut self.shared,
            |queue, shared| {

                egui::TopBottomPanel::top("menu_panel").show(ctx, |ui| {
                    // TODO obviously split this monolith up later lol
                    egui::MenuBar::new().ui(ui, |ui| {
                        ui.menu_button("File", |ui| {
                            let menu_width = [ // TODO HORRIBLE WAY OF DOING THIS. APPLY DRY AFTER DONE PROTOTYPING
                                menu_item_width(ui, "New Project...", "Ctrl+N"),
                                menu_item_width(ui, "Open Project...", "Ctrl+O"),
                                menu_item_width(ui, "Save Project", "Ctrl+S"),
                                menu_item_width(ui, "Save Project As...", "Ctrl+Shift+S"),
                                menu_item_width(ui, "Settings", "Ctrl+,"),
                                menu_item_width(ui, "Close Scene", "Ctrl+W"),
                                menu_item_width(ui, "Close Project", "Ctrl+Shift+W"),

                            ]
                            .into_iter()
                            .fold(0.0, f32::max);

                            ui.set_min_width(menu_width);
                            ui.shrink_width_to_current();

                            menu_item_with_shortcut(ui, "New Project...", "Ctrl+N");
                            ui.separator();
                            menu_item_with_shortcut(ui, "Open Project...", "Ctrl+O");
                            ui.menu_button("Open Recent", |ui| {
                                ui.button("~/Documents/framebolt/not-a-real-project");
                                ui.button("~/Documents/framebolt/also-not-a-real-project");
                                ui.button("~/Documents/framebolt/hentai");
                                ui.button("~/Documents/framebolt/idk");
                            });
                            ui.separator();
                            menu_item_with_shortcut(ui, "Save Project", "Ctrl+S");
                            menu_item_with_shortcut(ui, "Save Project As...", "Ctrl+Shift+S");
                            ui.separator();
                            ui.button("Export...");
                            ui.separator();
                            ui.button("Auto Save");
                            menu_item_with_shortcut(ui, "Settings", "Ctrl+,");
                            ui.separator();
                            menu_item_with_shortcut(ui, "Close Scene", "Ctrl+W");
                            menu_item_with_shortcut(ui, "Close Project", "Ctrl+Shift+W");
                            ui.separator();
                            
                            if ui.button("Quit").clicked() {
                                ui.ctx().send_viewport_cmd(egui::ViewportCommand::Close);
                            }
                        });

                        ui.menu_button("Edit", |ui| {
                            let menu_width = [ // TODO HORRIBLE WAY OF DOING THIS. APPLY DRY AFTER DONE PROTOTYPING
                                menu_item_width(ui, "Undo", "Ctrl+Z"),
                                menu_item_width(ui, "Redo", "Ctrl+Y"),
                            ]
                            .into_iter()
                            .fold(0.0, f32::max);

                            ui.set_min_width(menu_width);
                            ui.shrink_width_to_current();
                            
                            menu_item_with_shortcut(ui, "Undo", "Ctrl+Z");
                            menu_item_with_shortcut(ui, "Redo", "Ctrl+Y");
                        })
                    });
                });
                

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