use eframe::egui::PaintCallbackInfo;
use eframe::egui_wgpu::CallbackTrait;

use crate::renderer::SharedRenderer;

pub struct MyCallback {
    pub(crate) renderer: SharedRenderer,
}

impl CallbackTrait for MyCallback {
    fn paint(
        &self,
        info: PaintCallbackInfo,
        render_pass: &mut wgpu::RenderPass<'static>,
        _callback_resources: &type_map::concurrent::TypeMap,
    ) {
        let renderer = self.renderer.lock();

        let vp = info.viewport_in_pixels();

        render_pass.set_scissor_rect(
            vp.left_px as u32,
            vp.top_px as u32,
            vp.width_px as u32,
            vp.height_px as u32,
        );

        renderer.render_to_render_pass(render_pass);
    }
}
