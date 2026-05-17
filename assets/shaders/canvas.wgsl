struct Camera {
    view_proj: mat4x4<f32>,
};

@group(0) @binding(0)
var<uniform> camera: Camera;

struct VertexInput {
    @location(0) position: vec2<f32>,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
};

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    let world = vec4<f32>(input.position, 0.0, 1.0);
    out.clip_position = camera.view_proj * world;

    return out;
}

@fragment
fn fs_main() -> @location(0) vec4<f32> {
    return vec4(0.9, 0.9, 0.9, 1.0); // canvas color
}