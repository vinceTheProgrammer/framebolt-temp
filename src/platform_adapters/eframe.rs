use framebolt_egui::renderer::RenderContext;

use crate::FrameboltApp;

pub struct FrameboltEframeAdapter {
    pub app: FrameboltApp,
}

impl eframe::App for FrameboltEframeAdapter {
    fn update(
        &mut self,
        ctx: &egui::Context,
        frame: &mut eframe::Frame,
    ) {
        let Some(render_state) = frame.wgpu_render_state() else {
            return;
        };

        let mut render = RenderContext {
            device: &render_state.device,
            queue: &render_state.queue,
            target_format: render_state.target_format,
        };

        self.app.render(ctx, &mut render);
    }
}