use eframe::egui::{self, Align, Layout, RichText, Vec2};

use egui_phosphor::regular::{
    ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT, ARROW_UP, BACKSPACE, EYE, EYE_SLASH, PAUSE, PLAY,
    PLUS_SQUARE, STACK_PLUS, TRASH,
};

use crate::panels::{Panel, PanelContext, PanelId};

#[derive(Clone)]
pub struct Layer {
    pub name: String,
    pub visible: bool,
}

pub struct TimelinePanel {
    pub layers: Vec<Layer>,

    pub current_layer: usize,
    pub current_frame: usize,

    pub frame_count: usize,
    pub playing: bool,
}

impl Default for TimelinePanel {
    fn default() -> Self {
        Self {
            current_layer: 0,
            current_frame: 0,

            frame_count: 24,
            playing: false,

            layers: vec![
                Layer {
                    name: "Sketch".into(),
                    visible: true,
                },
                Layer {
                    name: "Lineart".into(),
                    visible: true,
                },
                Layer {
                    name: "Color".into(),
                    visible: true,
                },
                Layer {
                    name: "Shadows".into(),
                    visible: true,
                },
            ],
        }
    }
}

impl Panel for TimelinePanel {
    fn id(&self) -> PanelId {
        PanelId::Timeline
    }

    fn title(&self) -> &'static str {
        "Timeline"
    }

    fn ui(&mut self, ui: &mut egui::Ui, _ctx: &mut PanelContext) {
        let available = ui.available_size();

        let horizontal = available.x >= available.y;

        let compact = if horizontal {
            available.y < 180.0
        } else {
            available.x < 220.0
        };

        ui.vertical(|ui| {
            ui.set_height(ui.available_height());

            self.top_bar(ui);

            ui.separator();

            if compact {
                self.compact_view(ui, horizontal);
            } else {
                ui.allocate_ui(ui.available_size(), |ui| {
                    self.full_view(ui, horizontal);
                });
            }
        });
    }
}

impl TimelinePanel {
    fn top_bar(&mut self, ui: &mut egui::Ui) {
        ui.set_height(40.0);

        ui.horizontal(|ui| {
            let icon_size = [32.0, 32.0];

            let play_icon = if self.playing { PAUSE } else { PLAY };

            if ui
                .add_sized(icon_size, egui::Button::new(play_icon))
                .clicked()
            {
                self.playing = !self.playing;
            }

            if ui
                .add_sized(icon_size, egui::Button::new(PLUS_SQUARE))
                .clicked()
            {
                self.add_frame();
            }

            if ui
                .add_sized(icon_size, egui::Button::new(STACK_PLUS))
                .clicked()
            {
                self.add_layer();
            }

            ui.separator();

            ui.label(RichText::new(format!("Frame {}", self.current_frame + 1)).strong());

            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                ui.label(format!("{} Layers", self.layers.len()));
            });
        });
    }

    fn compact_view(&mut self, ui: &mut egui::Ui, horizontal: bool) {
        if self.layers.is_empty() {
            ui.centered_and_justified(|ui| {
                ui.label("No layers");
            });

            return;
        }

        let layer_index = self.current_layer.min(self.layers.len() - 1);

        let visible = self.layers[layer_index].visible;

        let icon_size = [32.0, 32.0];

        if horizontal {
            ui.horizontal(|ui| {
                ui.vertical(|ui| {
                    if ui
                        .add_sized(icon_size, egui::Button::new(ARROW_UP))
                        .clicked()
                    {
                        self.prev_layer();
                    }
                    if ui
                        .add_sized(icon_size, egui::Button::new(ARROW_DOWN))
                        .clicked()
                    {
                        self.next_layer();
                    }
                });
                ui.vertical(|ui| {
                    if ui.add_sized(icon_size, egui::Button::new(TRASH)).clicked() {
                        self.delete_layer(layer_index);
                    }
                    let visibility_icon = if visible { EYE } else { EYE_SLASH };

                    if ui
                        .add_sized(icon_size, egui::Button::new(visibility_icon))
                        .clicked()
                    {
                        self.layers[layer_index].visible = !self.layers[layer_index].visible;
                    }
                });
                ui.separator();

                ui.vertical(|ui| {
                    self.layer_header_horizontal(ui, layer_index);

                    self.horizontal_frame_strip(ui, layer_index);
                });
            });
        } else {
            ui.vertical_centered(|ui| {
                ui.vertical(|ui| {
                    ui.horizontal(|ui| {
                        if ui
                            .add_sized(icon_size, egui::Button::new(ARROW_LEFT))
                            .clicked()
                        {
                            self.prev_layer();
                        }
                        if ui
                            .add_sized(icon_size, egui::Button::new(ARROW_RIGHT))
                            .clicked()
                        {
                            self.next_layer();
                        }
                    });
                    ui.horizontal(|ui| {
                        let visibility_icon = if visible { EYE } else { EYE_SLASH };

                        if ui
                            .add_sized(icon_size, egui::Button::new(visibility_icon))
                            .clicked()
                        {
                            self.layers[layer_index].visible = !self.layers[layer_index].visible;
                        }

                        if ui.add_sized(icon_size, egui::Button::new(TRASH)).clicked() {
                            self.delete_layer(layer_index);
                        }
                    });
                    ui.label(&self.layers[layer_index].name);
                });

                ui.separator();

                self.vertical_frame_strip(ui, layer_index);
            });
        }
    }

    fn full_view(&mut self, ui: &mut egui::Ui, horizontal: bool) {
        ui.set_width(ui.available_width());
        ui.set_height(ui.available_height());
        let available = ui.available_size();

        ui.allocate_ui(available, |ui| {
            if horizontal {
                egui::ScrollArea::vertical()
                    .id_salt("timeline_vertical_scroll")
                    .auto_shrink([false; 2])
                    .show(ui, |ui| {
                        for i in 0..self.layers.len() {
                            ui.push_id(i, |ui| {
                                self.horizontal_layer(ui, i);
                            });

                            ui.add_space(6.0);
                        }
                    });
            } else {
                egui::ScrollArea::horizontal()
                    .id_salt("timeline_horizontal_scroll")
                    .auto_shrink([false; 2])
                    .show(ui, |ui| {
                        ui.horizontal(|ui| {
                            for i in 0..self.layers.len() {
                                ui.push_id(i, |ui| {
                                    self.vertical_layer(ui, i);
                                });

                                ui.add_space(8.0);
                            }
                        });
                    });
            }
        });
    }

    fn horizontal_layer(&mut self, ui: &mut egui::Ui, layer_index: usize) {
        ui.group(|ui| {
            ui.set_width(ui.available_width());

            ui.horizontal(|ui| {
                ui.allocate_ui_with_layout(
                    Vec2::new(170.0, 72.0),
                    Layout::top_down(Align::LEFT),
                    |ui| {
                        self.layer_header_horizontal(ui, layer_index);
                    },
                );

                ui.separator();

                egui::ScrollArea::horizontal()
                    .auto_shrink([false; 2])
                    .show(ui, |ui| {
                        self.horizontal_frame_strip(ui, layer_index);
                    });
            });
        });
    }

    fn vertical_layer(&mut self, ui: &mut egui::Ui, layer_index: usize) {
        ui.group(|ui| {
            ui.allocate_ui_with_layout(
                Vec2::new(120.0, 120.0),
                Layout::top_down(Align::Center),
                |ui| {
                    self.layer_header_vertical(ui, layer_index);
                },
            );

            ui.separator();

            egui::ScrollArea::vertical()
                .auto_shrink([false; 2])
                .show(ui, |ui| {
                    self.vertical_frame_strip(ui, layer_index);
                });
        });
    }

    fn layer_header_horizontal(&mut self, ui: &mut egui::Ui, layer_index: usize) {
        let layer_name = self.layers[layer_index].name.clone();

        ui.horizontal(|ui| {
            ui.label(RichText::new(layer_name).strong());

            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                if ui.button(BACKSPACE).clicked() {
                    self.delete_frame(self.current_frame);
                }
            });
        });
    }

    fn layer_header_vertical(&mut self, ui: &mut egui::Ui, layer_index: usize) {
        let layer_name = self.layers[layer_index].name.clone();

        ui.vertical_centered(|ui| {
            ui.label(RichText::new(layer_name).strong());

            if ui.button(BACKSPACE).clicked() {
                self.delete_frame(self.current_frame);
            }
        });
    }

    fn horizontal_frame_strip(&mut self, ui: &mut egui::Ui, layer_index: usize) {
        ui.horizontal(|ui| {
            for frame_index in 0..self.frame_count {
                ui.push_id(frame_index, |ui| {
                    self.frame_button(ui, layer_index, frame_index);
                });
            }
        });
    }

    fn vertical_frame_strip(&mut self, ui: &mut egui::Ui, layer_index: usize) {
        ui.vertical(|ui| {
            for frame_index in 0..self.frame_count {
                ui.push_id(frame_index, |ui| {
                    self.frame_button(ui, layer_index, frame_index);
                });
            }
        });
    }

    fn frame_button(&mut self, ui: &mut egui::Ui, layer_index: usize, frame_index: usize) {
        let selected = self.current_frame == frame_index && self.current_layer == layer_index;

        let response = ui.add_sized(
            [64.0, 36.0],
            egui::Button::new((frame_index + 1).to_string()).selected(selected),
        );

        if response.clicked() {
            self.current_frame = frame_index;

            self.current_layer = layer_index;
        }
    }

    fn add_frame(&mut self) {
        self.frame_count += 1;
    }

    fn add_layer(&mut self) {
        self.layers.push(Layer {
            name: format!("Layer {}", self.layers.len() + 1,),
            visible: true,
        });
    }

    fn delete_layer(&mut self, layer_index: usize) {
        if self.layers.len() <= 1 {
            return;
        }

        self.layers.remove(layer_index);

        self.current_layer = self.current_layer.min(self.layers.len() - 1);
    }

    fn delete_frame(&mut self, _frame_index: usize) {
        if self.frame_count <= 1 {
            return;
        }

        self.frame_count -= 1;

        self.current_frame = self.current_frame.min(self.frame_count - 1);
    }

    fn prev_layer(&mut self) {
        if self.layers.is_empty() {
            return;
        }

        if self.current_layer == 0 {
            self.current_layer = self.layers.len() - 1;
        } else {
            self.current_layer -= 1;
        }
    }

    fn next_layer(&mut self) {
        if self.layers.is_empty() {
            return;
        }

        self.current_layer = (self.current_layer + 1) % self.layers.len();
    }
}
