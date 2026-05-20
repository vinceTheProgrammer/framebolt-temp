use eframe::egui_wgpu;
use wgpu::Queue;

use crate::{callback::MyCallback, input::handle_canvas_input, renderer::SharedRenderer};

pub fn canvas_viewport(
    ui: &mut eframe::egui::Ui,
    renderer: SharedRenderer,
    queue: Option<&Queue>,
) {
    let size = ui.available_size();

    let (rect, _response) = ui.allocate_exact_size(size, eframe::egui::Sense::drag());

    handle_canvas_input(ui, renderer.clone(), rect);

    if let Some(queue) = queue {
        let ppp = ui.ctx().pixels_per_point();

        renderer.lock().update_camera(
            &queue,
            rect.width() * ppp,
            rect.height() * ppp,
        );
    }
    
    let callback = egui_wgpu::Callback::new_paint_callback(
        rect,
        MyCallback {
            renderer: renderer.clone(),
        }
    );

    ui.painter().add(callback);
}