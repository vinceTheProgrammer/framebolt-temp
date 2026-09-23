use eframe::{
    egui,
    wgpu::Queue,
};

use framebolt_egui::{
    app::SharedApp,
    panels::{
        PanelContext,
        PanelId,
        PanelLocation,
        PanelRegistry,
        Platform,
    },
};


pub fn show(
    ctx: &egui::Context,
    queue: &Queue,
    shared: &mut SharedApp,
    panels: &mut PanelRegistry,
    show_left: bool,
    _show_right: bool,
    show_bottom: bool,
    _show_top: bool,
) {
    let default_width = 70.0;
    let default_height = 160.0;

    if show_left {
        egui::SidePanel::left("tools_panel")
            .resizable(false)
            .default_width(default_width)
            .show(ctx, |ui| {
                if let Some(panel) =
                    panels.panel_mut(PanelId::Tools)
                {
                    let mut panel_ctx = PanelContext {
                        platform: Platform::Mobile,
                        shared,
                        panel_location: PanelLocation::Left,
                        queue: Some(queue),
                    };

                    panel.ui(ui, &mut panel_ctx);
                }
            });
    }

    if show_bottom {
        egui::TopBottomPanel::bottom("timeline_panel")
            .resizable(false)
            .default_height(default_height)
            .min_height(default_height * 0.75)
            .max_height(default_height * 1.5)
            .show(ctx, |ui| {
                if let Some(panel) =
                    panels.panel_mut(PanelId::Timeline)
                {
                    let mut panel_ctx = PanelContext {
                        platform: Platform::Mobile,
                        shared,
                        panel_location: PanelLocation::Bottom,
                        queue: Some(queue),
                    };

                    panel.ui(ui, &mut panel_ctx);
                }
            });
    }

    egui::CentralPanel::default().show(ctx, |ui| {
        if let Some(panel) =
            panels.panel_mut(PanelId::Canvas)
        {
            let mut panel_ctx = PanelContext {
                platform: Platform::Mobile,
                shared,
                panel_location: PanelLocation::Center,
                queue: Some(queue),
            };

            panel.ui(ui, &mut panel_ctx);
        }
    });
}