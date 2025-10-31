@header const math = @import("../../lib/math.zig")
@ctype mat4 math.Mat4

@vs vs
layout(binding = 0) uniform vs_params { mat4 mvp; };
in vec4 position; in vec4 color0;
out vec4 color; out vec3 world_pos;
void main() {
    gl_Position = mvp * position;
    world_pos = position.xyz;
    color = color0;
}
@end

@fs fs
in vec4 color; in vec3 world_pos;
out vec4 frag_color;

// Interleaved gradient dithering - adapted from Portal 2 X360
vec3 screenSpaceDither(vec2 screenPos) {
    // Iestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified
    vec3 dither = dot(vec2(171.0, 231.0), screenPos).xxx;
    dither.rgb = fract(dither.rgb / vec3(103.0, 71.0, 97.0)) - vec3(0.5);
    return (dither.rgb / 255.0) * 0.375;
}

void main() {
    vec3 n = normalize(cross(dFdx(world_pos), dFdy(world_pos)));
    
    // Get UV coordinates for the current face
    vec2 uv = (abs(n.x) > 0.5) ? world_pos.yz : (abs(n.y) > 0.5) ? world_pos.xz : world_pos.xy;
    
    // Create thick sharp voxel outline
    vec2 grid = fract(uv);
    float outline = min(min(grid.x, 1.0 - grid.x), min(grid.y, 1.0 - grid.y));
    float edge = smoothstep(0.05, 0.06, outline);
    
    // Simple lighting
    float light = dot(n, normalize(vec3(0.6, 1.0, 0.4))) * 0.4 + 0.6;
    
    // Apply dithering
    vec3 dither = screenSpaceDither(gl_FragCoord.xy);
    vec3 finalColor = color.rgb * edge * light + dither;
    
    frag_color = vec4(finalColor, color.a);
}
@end

@program cube vs fs
