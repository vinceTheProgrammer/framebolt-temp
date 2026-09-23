use eframe::egui;
use framebolt_canvas::CameraCommand;

use crate::{
    panels::{Platform, canvas::CanvasInteractionState},
    renderer::SharedRenderer,
};

pub fn handle_canvas_input(
    ui: &mut egui::Ui,
    renderer: SharedRenderer,
    interaction: &mut CanvasInteractionState,
    platform: Platform,
    rect: egui::Rect,
    response: &egui::Response,
) {
    let active = response.hovered() || response.dragged() || response.contains_pointer();

    if !active {
        return;
    }

    match platform {
        Platform::Desktop => {
            handle_desktop_canvas_input(ui, renderer, interaction, rect, response);
        }

        Platform::Mobile => {
            handle_mobile_canvas_input(ui, renderer, interaction, rect, response);
        }
    }
}

fn handle_desktop_canvas_input(
    ui: &mut egui::Ui,
    renderer: SharedRenderer,
    interaction: &mut CanvasInteractionState,
    rect: egui::Rect,
    response: &egui::Response,
) {
    let viewport = rect.size();

    let mut cmd = CameraCommand::default();

    // Mouse wheel / trackpad zoom
    const SCROLL_SCALE_FACTOR: f32 = 0.01;
    const OFFSET_SO_1_AT_REST: f32 = 1.0;
    let zoom_delta =
        ui.input(|i| i.smooth_scroll_delta.y * SCROLL_SCALE_FACTOR + OFFSET_SO_1_AT_REST);

    if (zoom_delta - 1.0).abs() > 0.001 {
        cmd.zoom_factor = 1.0 + (zoom_delta - 1.0) * 0.75;

        if let Some(pos) = response.hover_pos() {
            let local = pos - rect.min;

            cmd.pivot = glam::vec2(local.x, local.y);
        }
    }

    // Mouse interactions
    if let Some(pos) = response.interact_pointer_pos() {
        let local = pos - rect.min;

        let local_pivot = glam::vec2(local.x, local.y);

        // Pan
        if response.dragged_by(egui::PointerButton::Primary) {
            let delta = ui.input(|i| i.pointer.delta());

            cmd.pan = glam::vec2(delta.x, -delta.y);

            cmd.pivot = local_pivot;
        }

        // Rotation begin
        if interaction.rotation_pivot.is_none()
            && response.drag_started_by(egui::PointerButton::Secondary)
        {
            interaction.rotation_pivot = Some(local_pivot);
        }

        // Rotate
        if response.dragged_by(egui::PointerButton::Secondary) {
            let delta = ui.input(|i| i.pointer.delta());

            cmd.rotate_delta = delta.x * -0.005;

            if let Some(pivot) = interaction.rotation_pivot {
                cmd.pivot = pivot;
            }
        }

        // Rotation end
        if response.drag_stopped_by(egui::PointerButton::Secondary) {
            interaction.rotation_pivot = None;
        }
    }

    apply_camera_command_if_needed(renderer, cmd, viewport);
}

fn handle_mobile_canvas_input(
    ui: &mut egui::Ui,
    renderer: SharedRenderer,
    interaction: &mut CanvasInteractionState,
    rect: egui::Rect,
    _response: &egui::Response,
) {
    let viewport = rect.size();

    if let Some(multi_touch) = ui.input(|i| i.multi_touch()) {
        let mut cmd = CameraCommand::default();

        let center = multi_touch.center_pos;

        let local_center = center - rect.min;

        cmd.pivot = glam::vec2(local_center.x, local_center.y);

        // =====================================
        // PAN FROM ACTUAL CENTER MOVEMENT
        // =====================================

        if let Some(last_center) = interaction.last_touch_center {
            let delta = center - last_center;

            cmd.pan = glam::vec2(delta.x, -delta.y) * 2.0; // todo figure out why this is needed for panning to feel close to actually pinned
        }

        interaction.last_touch_center = Some(center);

        // =====================================
        // ZOOM
        // =====================================

        cmd.zoom_factor = multi_touch.zoom_delta;

        // =====================================
        // ROTATE
        // =====================================

        cmd.rotate_delta = multi_touch.rotation_delta;

        apply_camera_command_if_needed(renderer, cmd, viewport);
    } else {
        interaction.last_touch_center = None;
    }
}

fn apply_camera_command_if_needed(
    renderer: SharedRenderer,
    cmd: CameraCommand,
    viewport: egui::Vec2,
) {
    if cmd.pan != glam::Vec2::ZERO
        || (cmd.zoom_factor - 1.0).abs() > 0.001
        || cmd.rotate_delta.abs() > 0.0001
    {
        renderer
            .lock()
            .apply_camera_command(cmd, viewport.x, viewport.y);
    }
}
