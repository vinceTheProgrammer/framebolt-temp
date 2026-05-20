use framebolt_canvas::{CameraCommand};

use crate::renderer::SharedRenderer;

pub fn handle_canvas_input(
    ui: &mut eframe::egui::Ui,
    renderer: SharedRenderer, // or whatever your locked type is
    rect: eframe::egui::Rect,
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