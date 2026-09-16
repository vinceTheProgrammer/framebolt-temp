use eframe::egui;

use crate::panels::Panel;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tool {
    Brush,
    Eraser,
    Fill,
    Eyedropper,
    Move,
    Rotate,
    Scale,
    Rectangle,
    Ellipse,
    Lasso,
}

pub struct ToolsPanel {
    pub selected_tool: Tool,
}

impl Panel for ToolsPanel {
    fn id(&self) -> super::PanelId {
        super::PanelId::Tools
    }

    fn title(&self) -> &'static str {
        "Tools"
    }

    fn ui(
        &mut self,
        ui: &mut egui::Ui,
        _ctx: &mut super::PanelContext,
    ) {
        let available = ui.available_size();

        let compact_width = available.x < 100.0;
        let compact_height = available.y < 100.0;

        let tools = [
            (Tool::Brush, egui_phosphor::regular::PAINT_BRUSH, "Brush"),
            (Tool::Eraser, egui_phosphor::regular::ERASER, "Eraser"),
            (Tool::Fill, egui_phosphor::regular::PAINT_BUCKET, "Fill"),
            (Tool::Eyedropper, egui_phosphor::regular::EYEDROPPER, "Eyedropper"),
            (Tool::Move, egui_phosphor::regular::HAND, "Move"),
            (Tool::Rotate, egui_phosphor::regular::ARROWS_CLOCKWISE, "Rotate"),
            (Tool::Scale, egui_phosphor::regular::RULER, "Scale"),
            (Tool::Rectangle, egui_phosphor::regular::RECTANGLE, "Rectangle"),
            (Tool::Ellipse, egui_phosphor::regular::CIRCLE, "Ellipse"),
            (Tool::Lasso, egui_phosphor::regular::LASSO, "Lasso"),
        ];

        ui.add_space(6.0);

        let icon_size = if compact_width || compact_height {
            24.0
        } else {
            18.0
        };

        // Horizontal toolbar mode
        if compact_height {
            egui::ScrollArea::horizontal()
                .auto_shrink([false, false])
                .show(ui, |ui| {
                    ui.horizontal(|ui| {
                        for (tool, icon, label) in tools {
                            self.tool_icon_button(
                                ui,
                                tool,
                                icon,
                                label,
                                icon_size,
                            );
                        }
                    });
                });

            return;
        }

        // Vertical thin sidebar mode
        if compact_width {
            egui::ScrollArea::vertical()
                .auto_shrink([false, false])
                .show(ui, |ui| {
                    ui.vertical_centered(|ui| {
                        for (tool, icon, label) in tools {
                            self.tool_icon_button(
                                ui,
                                tool,
                                icon,
                                label,
                                icon_size,
                            );

                            ui.add_space(4.0);
                        }
                    });
                });

            return;
        }

        // Normal desktop-ish mode
        egui::ScrollArea::vertical().show(ui, |ui| {
            for (tool, icon, label) in tools {
                self.tool_button(
                    ui,
                    tool,
                    icon,
                    label,
                );

                ui.add_space(4.0);
            }
        });
    }
}

impl Default for ToolsPanel {
    fn default() -> Self {
        Self {
            selected_tool: Tool::Brush,
        }
    }
}

impl ToolsPanel {
    fn tool_button(
        &mut self,
        ui: &mut egui::Ui,
        tool: Tool,
        icon: &str,
        label: &str,
    ) {
        let selected = self.selected_tool == tool;
    
        let text = format!("{icon}  {label}");
    
        let response =
            ui.selectable_label(selected, text);
    
        if response.clicked() {
            self.selected_tool = tool;
        }
    }

    fn tool_icon_button(
        &mut self,
        ui: &mut egui::Ui,
        tool: Tool,
        icon: &str,
        label: &str,
        size: f32,
    ) {
        let selected = self.selected_tool == tool;
    
        let button = egui::Button::new(
            egui::RichText::new(icon).size(size)
        )
        .min_size(egui::vec2(size + 16.0, size + 16.0))
        .selected(selected);
    
        let response = ui.add(button);
    
        if response.clicked() {
            self.selected_tool = tool;
        }
    
        response.on_hover_text(label);
    }
}