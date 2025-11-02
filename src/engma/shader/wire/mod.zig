const shader_impl = @import("shader.glsl.zig");

pub const desc = shader_impl.cubeShaderDesc;
pub const Params = shader_impl.VsParams;
pub const ATTR_position = shader_impl.ATTR_cube_position;
pub const ATTR_color = shader_impl.ATTR_cube_color0;
pub const UB_params = shader_impl.UB_vs_params;
