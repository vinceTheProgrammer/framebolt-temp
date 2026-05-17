use bytemuck::{Pod, Zeroable};
use glam::{Mat2, Mat4, Quat, Vec2};

pub struct CanvasRenderer {
    texture: Option<wgpu::Texture>,
    view: Option<wgpu::TextureView>,
    size: (u32, u32),
    pub pipeline: Option<wgpu::RenderPipeline>,
    format: wgpu::TextureFormat,
    camera: Camera2D,
    camera_buffer: Option<wgpu::Buffer>,
    camera_bind_group: Option<wgpu::BindGroup>,
    vertex_buffer: Option<wgpu::Buffer>,
}

impl CanvasRenderer {
    pub fn new(format: wgpu::TextureFormat) -> Self {
        Self {
            texture: None,
            view: None,
            size: (0, 0),
            format,
            pipeline: None,
            camera: Camera2D::default(),
            camera_buffer: None,
            camera_bind_group: None,
            vertex_buffer: None,
        }
    }

    pub fn init(
        &mut self,
        device: &wgpu::Device,
    ) {

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("../../../assets/shaders/canvas.wgsl").into()),
        });

        let camera_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("camera layout"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::VERTEX,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            }],
        });

        // todo look at whether create_buffer_init instead would be better
        let camera_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("camera buffer"),
            size: std::mem::size_of::<CameraUniform>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let camera_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("camera bind group"),
            layout: &camera_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: camera_buffer.as_entire_binding(),
            }],
        });

        let pipeline_descriptor = &wgpu::PipelineLayoutDescriptor {
            label: Some("Render Pipeline Layout"),
            bind_group_layouts: &[&camera_layout],
            push_constant_ranges: &[],
        };

        let render_pipeline_layout =
            device.create_pipeline_layout(pipeline_descriptor);

        let canvas_vertices = [
            Vertex { position: [-960.0, -540.0] }, // bottom-left
            Vertex { position: [ 960.0, -540.0] }, // bottom-right
            Vertex { position: [ 960.0,  540.0] }, // top-right

            Vertex { position: [-960.0, -540.0] }, // bottom-left
            Vertex { position: [ 960.0,  540.0] }, // top-right
            Vertex { position: [-960.0,  540.0] }, // top-left
        ];

        let vertex_buffer = wgpu::util::DeviceExt::create_buffer_init(device, &wgpu::util::BufferInitDescriptor {
            label: Some("canvas quad"),
            contents: bytemuck::cast_slice(&canvas_vertices),
            usage: wgpu::BufferUsages::VERTEX,
        });

        let pipeline_descriptor = &wgpu::RenderPipelineDescriptor {
            label: Some("Render Pipeline"),
            layout: Some(&render_pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_main"), // 1.
                buffers: &[wgpu::VertexBufferLayout {
                    array_stride: std::mem::size_of::<Vertex>() as u64,
                    step_mode: wgpu::VertexStepMode::Vertex,
                    attributes: &[
                        wgpu::VertexAttribute {
                            offset: 0,
                            shader_location: 0,
                            format: wgpu::VertexFormat::Float32x2,
                        },
                    ],
                }],
                compilation_options: wgpu::PipelineCompilationOptions::default(),
            },
            fragment: Some(wgpu::FragmentState { // 3.
                module: &shader,
                entry_point: Some("fs_main"),
                targets: &[Some(wgpu::ColorTargetState { // 4.
                    format: self.format,
                    blend: Some(wgpu::BlendState::REPLACE),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: wgpu::PipelineCompilationOptions::default(),
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList, // 1.
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw, // 2.
                cull_mode: Some(wgpu::Face::Back),
                // Setting this to anything other than Fill requires Features::NON_FILL_POLYGON_MODE
                polygon_mode: wgpu::PolygonMode::Fill,
                // Requires Features::DEPTH_CLIP_CONTROL
                unclipped_depth: false,
                // Requires Features::CONSERVATIVE_RASTERIZATION
                conservative: false,
            },
            depth_stencil: None, // 1.
            multisample: wgpu::MultisampleState {
                count: 1, // 2.
                mask: !0, // 3.
                alpha_to_coverage_enabled: false, // 4.
            },
            cache: None,
            multiview: None,
        };

        let render_pipeline = device.create_render_pipeline(pipeline_descriptor);

        self.pipeline = Some(render_pipeline);
        self.camera_buffer = Some(camera_buffer);
        self.camera_bind_group = Some(camera_bind_group);
        self.vertex_buffer = Some(vertex_buffer);
    }

    pub fn resize(
        &mut self,
        device: &wgpu::Device,
        width: u32,
        height: u32,
    ) {
        if self.size == (width, height) {
            return;
        }

        self.size = (width, height);

        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("canvas texture"),
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: self.format,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT
                | wgpu::TextureUsages::TEXTURE_BINDING,
            view_formats: &[],
        });

        let view = texture.create_view(&Default::default());

        self.texture = Some(texture);
        self.view = Some(view);
    }

    pub fn render(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
    ) {
        let view = self.view.as_ref().unwrap();

        let mut encoder =
            device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("encoder"),
            });

        {
            let render_pass_descriptor = &wgpu::RenderPassDescriptor {
                label: Some("Render Pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    depth_slice: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color {
                            r: 0.05,
                            g: 0.05,
                            b: 0.06,
                            a: 1.0,
                        }),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                occlusion_query_set: None,
                timestamp_writes: None,
            };

            let mut render_pass = encoder.begin_render_pass(render_pass_descriptor);

            self.render_to_render_pass(&mut render_pass);
        }

        queue.submit(Some(encoder.finish()));
    }

    pub fn apply_camera_command(&mut self, command: CameraCommand, width: f32, height: f32) {
        self.camera.apply(command, glam::vec2(width, height));
    }
    
    pub fn update_camera(&mut self, queue: &wgpu::Queue, width: f32, height: f32) {
        let view = Mat4::from_translation(-self.camera.position.extend(0.0))
                 * Mat4::from_quat(Quat::from_rotation_z(-self.camera.rotation)); // inverse rotation
    
        let proj = Mat4::orthographic_rh(
            -width / (2.0 * self.camera.zoom),
             width / (2.0 * self.camera.zoom),
            -height / (2.0 * self.camera.zoom),
             height / (2.0 * self.camera.zoom),
            -1.0,
             1.0,
        );
    
        let view_proj = proj * view;
    
        let uniform = CameraUniform {
            view_proj: view_proj.to_cols_array_2d(),
        };
    
        queue.write_buffer(
            self.camera_buffer.as_ref().unwrap(),
            0,
            bytemuck::cast_slice(&[uniform]),
        );
    }

    pub fn render_to_render_pass(&self, render_pass: &mut wgpu::RenderPass<'_>) {
        let pipeline = self.pipeline.as_ref().unwrap();

        render_pass.set_pipeline(pipeline);
        render_pass.set_bind_group(0, self.camera_bind_group.as_ref().unwrap(), &[]);
        render_pass.set_vertex_buffer(0, self.vertex_buffer.as_ref().unwrap().slice(..));
        render_pass.draw(0..6, 0..1);
    }

    pub fn as_texture(&self) -> wgpu::Texture {
        self.texture.as_ref().unwrap().clone()
    }
}

#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
struct Vertex {
    position: [f32; 2],
}

#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
pub struct CameraUniform {
    pub view_proj: [[f32; 4]; 4],
}

#[derive(Debug, Clone, Copy)]
pub struct CameraCommand {
    pub pan: glam::Vec2,           // screen-space pixels
    pub zoom_factor: f32,    // multiplicative (1.0 = no change)
    pub rotate_delta: f32,   // radians
    pub pivot: glam::Vec2,         // screen-space point (for zoom + rotate)
}

impl Default for CameraCommand {
    fn default() -> Self {
        Self {
            pan: glam::Vec2::ZERO,
            zoom_factor: 1.0,
            rotate_delta: 0.0,
            pivot: glam::Vec2::ZERO,
        }
    }
}

#[derive(Debug)]
pub struct Camera2D {
    pub position: glam::Vec2,      // world space
    pub zoom: f32,           // pixels per world unit
    pub rotation: f32,       // radians
    pub min_zoom: f32,
    pub max_zoom: f32,
}

impl Default for Camera2D {
    fn default() -> Self {
        Self {
            position: Vec2::ZERO,
            zoom: 1.0,
            rotation: 0.0,
            min_zoom: 0.1,
            max_zoom: 20.0,
        }
    }
}

impl Camera2D {
    pub fn apply(&mut self, cmd: CameraCommand, viewport: Vec2) {
        // Pan
        self.position -= cmd.pan / self.zoom;

        // Rotation around pivot
        if cmd.rotate_delta.abs() > f32::EPSILON {
            let world_pivot = self.screen_to_world(cmd.pivot, viewport);
            let rot = Quat::from_rotation_z(cmd.rotate_delta);

            let diff = (self.position - world_pivot).extend(0.0);
            self.position = world_pivot + (rot * diff).truncate();

            self.rotation = (self.rotation + cmd.rotate_delta).rem_euclid(std::f32::consts::TAU);
        }

        // Zoom around pivot
        if (cmd.zoom_factor - 1.0).abs() > f32::EPSILON {
            let world_before = self.screen_to_world(cmd.pivot, viewport);

            self.zoom = (self.zoom * cmd.zoom_factor)
                .clamp(self.min_zoom, self.max_zoom);

            let world_after = self.screen_to_world(cmd.pivot, viewport);
            self.position += world_before - world_after;
        }
    }

    pub fn screen_to_world(&self, screen: Vec2, viewport: Vec2) -> Vec2 {
        let centered = Vec2::new(
            screen.x - viewport.x * 0.5,
            viewport.y * 0.5 - screen.y,
        );

        // Rotate inverse, then scale + translate
        let rotated = Mat2::from_angle(-self.rotation) * centered;
        rotated / self.zoom + self.position
    }

    pub fn world_to_screen(&self, world: Vec2, viewport: Vec2) -> Vec2 {
        let relative = (world - self.position) * self.zoom;
        let rotated = Mat2::from_angle(self.rotation) * relative;

        Vec2::new(
            viewport.x * 0.5 + rotated.x,
            viewport.y * 0.5 - rotated.y,
        )
    }

    pub fn reset(&mut self) {
        *self = Self::default();
    }
}