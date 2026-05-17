use std::sync::Arc;

use eframe::{egui_wgpu::{self, CallbackTrait}, wgpu::{self, Queue}};
use egui::{PaintCallbackInfo, mutex::Mutex};
use egui_dock::{DockArea, DockState};
use framebolt_canvas::{CameraCommand, CanvasRenderer};

pub struct FrameboltApp {
    dock_state: DockState<Tab>,
    renderer: Arc<Mutex<CanvasRenderer>>,
}

#[derive(Clone)]
pub enum Tab {
    Tools,
    Timeline,
    Canvas,
}

impl FrameboltApp {
    pub fn new(_cc: &eframe::CreationContext<'_>) -> Self {
        let mut dock_state = DockState::new(vec![Tab::Canvas]);

        dock_state
            .main_surface_mut()
            .split_left(
                egui_dock::NodeIndex::root(),
                0.1,
                vec![Tab::Tools, Tab::Timeline],
            );

        Self {
            dock_state,
            renderer: Arc::new(Mutex::new(CanvasRenderer::new(wgpu::TextureFormat::Bgra8Unorm))), // ideally unify this texture format with mobile, but figure out why it crashes for certain formats
        }
    }
}

impl eframe::App for FrameboltApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {

        let mut queue: Option<&Queue> = None;

        if let Some(render_state) = frame.wgpu_render_state() {
            let device = &render_state.device;
            queue = Some(&render_state.queue);
    
            let mut renderer = self.renderer.lock();
    
            if renderer.pipeline.is_none() {
                renderer.init(device);
            }
        }
    
        ctx.request_repaint();
    
        DockArea::new(&mut self.dock_state)
            .show(ctx, &mut TabViewer {
                renderer: self.renderer.clone(),
                queue: queue.cloned()
            });
    }
}

struct TabViewer {
    renderer: Arc<Mutex<CanvasRenderer>>,
    queue: Option<Queue>,
}

impl egui_dock::TabViewer for TabViewer {
    type Tab = Tab;

    fn ui(&mut self, ui: &mut egui::Ui, tab: &mut Tab) {
        match tab {
            Tab::Canvas => {
                let size = ui.available_size();

                let (rect, _response) = ui.allocate_exact_size(size, egui::Sense::drag());

                
                handle_canvas_input(ui, self.renderer.clone(), rect);
                
                let callback = egui_wgpu::Callback::new_paint_callback(
                    rect,
                    MyCallback {
                        renderer: self.renderer.clone(),
                        queue: self.queue.clone(),
                    }
                );

                ui.painter().add(callback);
            }

            Tab::Tools => {
                ui.heading("Tools");
            }

            Tab::Timeline => {
                ui.heading("Timeline");
            }
        }
    }

    fn title(&mut self, tab: &mut Tab) -> egui::WidgetText {
        match tab {
            Tab::Canvas => "Canvas".into(),
            Tab::Tools => "Tools".into(),
            Tab::Timeline => "Timeline".into(),
        }
    }
}

struct MyCallback {
    renderer: Arc<Mutex<CanvasRenderer>>,
    queue: Option<Queue>
}

impl CallbackTrait for MyCallback {
    fn paint(
        &self,
        info: PaintCallbackInfo,
        render_pass: &mut wgpu::RenderPass<'static>, 
        _callback_resources: &type_map::concurrent::TypeMap,
    ) {
        let mut renderer = self.renderer.lock();

        let vp = info.viewport_in_pixels();

        let width = vp.width_px as u32;
        let height = vp.height_px as u32;

        // let render_state = callback_resources
        //         .get::<eframe::egui_wgpu::RenderState>()
        //         .unwrap();

        if let Some(queue) = &self.queue {
            renderer.update_camera(&queue, width as f32, height as f32);
        }

        render_pass.set_scissor_rect(
            vp.left_px as u32,
            vp.top_px as u32,
            width,
            height,
        );

        renderer.render_to_render_pass(render_pass);
    }
}

fn handle_canvas_input(
    ui: &mut egui::Ui,
    renderer: Arc<Mutex<CanvasRenderer>>, // or whatever your locked type is
    rect: egui::Rect,
) {
    let pointer_pos = ui.input(|i| i.pointer.interact_pos());
    let viewport = rect.size();

    let mut cmd = CameraCommand {
        pivot: glam::Vec2::ZERO,
        ..Default::default()
    };

    if let Some(pos) = pointer_pos {
        let local_pos = pos - rect.min;
        cmd.pivot = glam::vec2(local_pos.x, local_pos.y);

        // === PAN ===
        if ui.input(|i| i.pointer.primary_down()) {
            let delta = ui.input(|i| i.pointer.delta());
            // Fix Y inversion + make movement 1:1 with finger/mouse
            cmd.pan = glam::vec2(delta.x, -delta.y);
        }

        // === ZOOM (mouse wheel + pinch) ===
        let zoom_delta = ui.input(|i| i.zoom_delta());
        if (zoom_delta - 1.0).abs() > 0.001 {
            cmd.zoom_factor = 1.0 + (zoom_delta - 1.0) * 0.75; // tune this multiplier
        }

        // === ROTATION ===
        // Desktop: secondary drag (right mouse)
        if ui.input(|i| i.pointer.secondary_down()) {
            let delta = ui.input(|i| i.pointer.delta());
            cmd.rotate_delta = delta.x * -0.005; // tune sensitivity
        }

        // Mobile: two-finger twist
        if let Some(multi_touch) = ui.input(|i| i.multi_touch()) {
            if multi_touch.num_touches == 2 {
                cmd.rotate_delta = multi_touch.rotation_delta; // egui gives us radians directly!
                
                // Optional: you can also blend in extra zoom from pinch if you want
                // cmd.zoom_factor *= multi_touch.zoom_delta;
            }
        }
    }

    // Apply only if something actually changed
    if cmd.pan != glam::Vec2::ZERO 
        || (cmd.zoom_factor - 1.0).abs() > 0.001 
        || cmd.rotate_delta.abs() > 0.0001 
    {
        renderer.lock().apply_camera_command(cmd, viewport.x, viewport.y);
    }
}