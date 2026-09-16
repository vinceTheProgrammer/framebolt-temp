use eframe::{egui, egui_wgpu};

use crate::{callback::MyCallback, input::handle_canvas_input, panels::{Panel, PanelContext, PanelId}};

pub struct CanvasPanel {
    interaction_state: CanvasInteractionState,
}

pub struct CanvasInteractionState {
    pub rotation_pivot: Option<glam::Vec2>,
    pub last_touch_center: Option<egui::Pos2>,
}

impl Default for CanvasPanel {
    fn default() -> Self {
        Self {
            interaction_state: CanvasInteractionState { rotation_pivot: None, last_touch_center: None }
        }
    }
}

impl Panel for CanvasPanel {
    fn id(&self) -> PanelId {
        PanelId::Canvas
    }

    fn title(&self) -> &'static str {
        "Canvas"
    }

    fn ui(
        &mut self,
        ui: &mut egui::Ui,
        ctx: &mut PanelContext,
    ) {
        let Some(renderer) =
            ctx.shared.renderer.as_ref()
        else {
            return;
        };

        let Some(queue) =
            ctx.queue
        else {
            return;
        };

        let size = ui.available_size();

        let (rect, response) =
            ui.allocate_exact_size(
                size,
                egui::Sense::drag(),
            );

        handle_canvas_input(
            ui,
            renderer.clone(),
            &mut self.interaction_state,
            ctx.platform,
            rect,
            &response
        );

        let ppp = ui.ctx().pixels_per_point();

        {
            let mut renderer_guard =
                renderer.lock();

            renderer_guard.update_camera(
                queue,
                rect.width() * ppp,
                rect.height() * ppp,
            );
        }

        let callback =
            egui_wgpu::Callback::new_paint_callback(
                rect,
                MyCallback {
                    renderer: renderer.clone(),
                },
            );

        ui.painter().add(callback);
    }
}