use eframe::egui;
use framebolt_egui::{app::SharedApp, panels::{PanelContext, PanelId, PanelLocation, PanelRegistry, Platform, canvas::CanvasPanel, timeline::TimelinePanel, tools::ToolsPanel}, renderer::prepare_renderer_then};
pub struct FrameboltMobileApp {
    shared: SharedApp,
    panels: PanelRegistry,
    show_left: bool,
    show_right: bool,
    show_bottom: bool,
    show_top: bool,
}

impl FrameboltMobileApp {
    pub fn new() -> Self {
        let mut panels = PanelRegistry::new();

        panels.register(Box::new(
            ToolsPanel::default()
        ));

        panels.register(Box::new(
            TimelinePanel::default()
        ));

        panels.register(Box::new(
            CanvasPanel::default()
        ));

        Self { 
            shared: SharedApp::default(),
            panels,
            show_left: true,
            show_bottom: true,
            show_right: false,
            show_top: false,
        }
    }
}

impl eframe::App for FrameboltMobileApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        prepare_renderer_then(ctx, frame, &mut self.shared, |queue, shared| {
                let default_width = 70.0;
                let default_height = 160.0;

                if self.show_left {
                    egui::SidePanel::left("tools_panel")
                        .resizable(false)
                        .default_width(default_width)
                        .show(ctx, |ui| {
                            if let Some(panel) =
                                self.panels.panel_mut(
                                    PanelId::Tools
                                )
                            {
                                let mut panel_ctx = PanelContext {
                                    platform: Platform::Mobile,
                                    shared: shared,
                                    panel_location: PanelLocation::Left,
                                    queue: Some(queue),
                                };
                
                                panel.ui(ui, &mut panel_ctx);
                            }
                        });
                }

                if self.show_bottom {
                    egui::TopBottomPanel::bottom(
                        "timeline_panel"
                    )
                    .resizable(false)
                    .default_height(default_height)
                    .min_height(default_height * 0.75)
                    .max_height(default_height * 1.5)
                    .show(ctx, |ui| {
                        if let Some(panel) =
                            self.panels.panel_mut(
                                PanelId::Timeline
                            )
                        {
                            let mut panel_ctx = PanelContext {
                                platform: Platform::Mobile,
                                shared: shared,
                                panel_location: PanelLocation::Bottom,
                                queue: Some(queue),
                            };
                
                            panel.ui(ui, &mut panel_ctx);
                        }
                    });
                }

                egui::CentralPanel::default().show(ctx, |ui| {
                    if let Some(panel) =
                        self.panels.panel_mut(
                            PanelId::Canvas
                        )
                    {
                        let mut panel_ctx = PanelContext {
                            platform: Platform::Mobile,
                            shared,
                            panel_location: PanelLocation::Center,
                            queue: Some(queue)
                        };

                        panel.ui(ui, &mut panel_ctx);
                    }
                });
            },
        );
    }
}

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
fn android_main(app: winit::platform::android::activity::AndroidApp) {
    let options = eframe::NativeOptions {
        android_app: Some(app),
        ..Default::default()
    };
    let _ = framebolt_egui::app::run_app(
        options,
        |_cc| FrameboltMobileApp::new(),
    );
}