use std::sync::Arc;

use egui::mutex::Mutex;
use framebolt_canvas::CanvasRenderer;

use crate::app::SharedApp;

pub type SharedRenderer = Arc<Mutex<CanvasRenderer>>;

pub struct RenderContext<'a> {
    pub device: &'a wgpu::Device,
    pub queue: &'a wgpu::Queue,
    pub target_format: wgpu::TextureFormat,
}

pub fn prepare_renderer_then<F>(
    ctx: &egui::Context,
    render: &RenderContext<'_>,
    shared: &mut SharedApp,
    f: F,
)
where
    F: FnOnce(&wgpu::Queue, &mut SharedApp),
{
    let renderer = shared
        .renderer
        .get_or_insert_with(|| {
            Arc::new(Mutex::new(CanvasRenderer::new()))
        });

    {
        let mut renderer_guard = renderer.lock();

        renderer_guard.ensure_initialized(
            render.device,
            render.target_format,
        );
    }

    ctx.request_repaint();

    f(render.queue, shared);
}
