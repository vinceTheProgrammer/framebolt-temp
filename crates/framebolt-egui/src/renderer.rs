use std::sync::Arc;

use eframe::egui::mutex::Mutex;
use framebolt_canvas::CanvasRenderer;

pub type SharedRenderer = Arc<Mutex<CanvasRenderer>>;

pub fn prepare_renderer_then<F>(
    ctx: &eframe::egui::Context,
    frame: &eframe::Frame,
    renderer: &mut Option<SharedRenderer>,
    f: F,
)
where
    F: FnOnce(&wgpu::Queue, SharedRenderer),
{
    if let Some(render_state) = frame.wgpu_render_state() {
        let device = &render_state.device;
        let queue = &render_state.queue;

        let renderer = renderer.get_or_insert_with(|| {
            Arc::new(Mutex::new(
                CanvasRenderer::new()
            ))
        });

        {
            let mut renderer_guard = renderer.lock();

            renderer_guard.ensure_initialized(device, render_state.target_format);
        }

        ctx.request_repaint();

        f(queue, Arc::clone(renderer));
    }
}