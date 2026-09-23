use eframe::{egui, wgpu::Queue};

use egui_dock::{DockArea, DockState};

use framebolt_core::dependency_report;

use framebolt_egui::{app::SharedApp,
    panels::{
        PanelContext,
        PanelId,
        PanelLocation,
        PanelRegistry,
        Platform,
    },
};


#[derive(Clone)]
pub struct DockTab {
    pub panel: PanelId,
}


pub fn create_dock_state() -> DockState<DockTab> {
    let mut dock_state = DockState::new(vec![
        DockTab {
            panel: PanelId::Canvas,
        },
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

    dock_state
}


pub fn show(
    ctx: &egui::Context,
    queue: &Queue,
    shared: &mut SharedApp,
    panels: &mut PanelRegistry,
    dock_state: &mut DockState<DockTab>,
) {
    show_menu_bar(ctx);

    DockArea::new(dock_state)
        .show(
            ctx,
            &mut TabViewer {
                shared,
                queue,
                panels,
            },
        );
}


fn show_menu_bar(ctx: &egui::Context) {
    egui::TopBottomPanel::top("menu_panel")
        .show(ctx, |ui| {
            egui::MenuBar::new().ui(ui, |ui| {

                ui.menu_button("File", |ui| {
                    let menu_width = [
                        menu_item_width(
                            ui,
                            "New Project...",
                            "Ctrl+N",
                        ),
                        menu_item_width(
                            ui,
                            "Open Project...",
                            "Ctrl+O",
                        ),
                        menu_item_width(
                            ui,
                            "Save Project",
                            "Ctrl+S",
                        ),
                        menu_item_width(
                            ui,
                            "Save Project As...",
                            "Ctrl+Shift+S",
                        ),
                        menu_item_width(
                            ui,
                            "Settings",
                            "Ctrl+,",
                        ),
                        menu_item_width(
                            ui,
                            "Close Scene",
                            "Ctrl+W",
                        ),
                        menu_item_width(
                            ui,
                            "Close Project",
                            "Ctrl+Shift+W",
                        ),
                    ]
                    .into_iter()
                    .fold(0.0, f32::max);

                    ui.set_min_width(menu_width);
                    ui.shrink_width_to_current();

                    menu_item_with_shortcut(
                        ui,
                        "New Project...",
                        "Ctrl+N",
                    );

                    ui.separator();

                    menu_item_with_shortcut(
                        ui,
                        "Open Project...",
                        "Ctrl+O",
                    );

                    ui.menu_button("Open Recent", |ui| {
                        let _ = ui.button(
                            "~/Documents/framebolt/not-a-real-project",
                        );

                        let _ = ui.button(
                            "~/Documents/framebolt/also-not-a-real-project",
                        );

                        let _ = ui.button(
                            "~/Documents/framebolt/hentai",
                        );

                        let _ = ui.button(
                            "~/Documents/framebolt/idk",
                        );
                    });

                    ui.separator();

                    menu_item_with_shortcut(
                        ui,
                        "Save Project",
                        "Ctrl+S",
                    );

                    menu_item_with_shortcut(
                        ui,
                        "Save Project As...",
                        "Ctrl+Shift+S",
                    );

                    ui.separator();

                    let _ = ui.button("Export...");

                    ui.separator();

                    let _ = ui.button("Auto Save");

                    menu_item_with_shortcut(
                        ui,
                        "Settings",
                        "Ctrl+,",
                    );

                    ui.separator();

                    menu_item_with_shortcut(
                        ui,
                        "Close Scene",
                        "Ctrl+W",
                    );

                    menu_item_with_shortcut(
                        ui,
                        "Close Project",
                        "Ctrl+Shift+W",
                    );

                    ui.separator();

                    if ui.button("Quit").clicked() {
                        ui.ctx().send_viewport_cmd(
                            egui::ViewportCommand::Close,
                        );
                    }
                });


                ui.menu_button("Edit", |ui| {
                    let menu_width = [
                        menu_item_width(
                            ui,
                            "Undo",
                            "Ctrl+Z",
                        ),
                        menu_item_width(
                            ui,
                            "Redo",
                            "Ctrl+Y",
                        ),
                    ]
                    .into_iter()
                    .fold(0.0, f32::max);

                    ui.set_min_width(menu_width);
                    ui.shrink_width_to_current();

                    menu_item_with_shortcut(
                        ui,
                        "Undo",
                        "Ctrl+Z",
                    );

                    menu_item_with_shortcut(
                        ui,
                        "Redo",
                        "Ctrl+Y",
                    );
                });


                ui.menu_button("Debug", |ui| {
                    ui.label(dependency_report());
                });
            });
        });
}


fn menu_item_with_shortcut(
    ui: &mut egui::Ui,
    label: &str,
    shortcut: &str,
) -> egui::Response {
    let font_id =
        egui::TextStyle::Button.resolve(ui.style());

    let (rect, response) =
        ui.allocate_exact_size(
            egui::vec2(
                ui.available_width(),
                ui.spacing().interact_size.y,
            ),
            egui::Sense::click(),
        );

    if ui.is_rect_visible(rect) {
        let visuals =
            if response.hovered() {
                &ui.visuals().widgets.hovered
            } else {
                &ui.visuals().widgets.inactive
            };

        let bg_fill =
            if response.hovered() {
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
            rect.left_center()
                + egui::vec2(2.0, 0.0),
            egui::Align2::LEFT_CENTER,
            label,
            font_id.clone(),
            visuals.text_color(),
        );

        if !shortcut.is_empty() {
            ui.painter().text(
                rect.right_center()
                    - egui::vec2(2.0, 0.0),
                egui::Align2::RIGHT_CENTER,
                shortcut,
                font_id,
                visuals.text_color()
                    .gamma_multiply(0.7),
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
    let font_id =
        egui::TextStyle::Button.resolve(ui.style());

    let label_width = ui
        .painter()
        .layout_no_wrap(
            label.to_owned(),
            font_id.clone(),
            ui.visuals().text_color(),
        )
        .size()
        .x;

    let shortcut_width =
        if shortcut.is_empty() {
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

    let spacing =
        if shortcut.is_empty() {
            0.0
        } else {
            24.0
        };

    4.0
        + label_width
        + spacing
        + shortcut_width
        + 4.0
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
            let mut panel_ctx = PanelContext {
                platform: Platform::Desktop,
                shared: self.shared,
                panel_location: PanelLocation::Docked,
                queue: Some(self.queue),
            };

            panel.ui(ui, &mut panel_ctx);
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