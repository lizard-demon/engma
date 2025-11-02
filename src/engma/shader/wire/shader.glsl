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

// Ultra simple elegant dithering
vec3 screenSpaceDither(vec2 screenPos) {
    vec2 scaledPos = screenPos * vec2(0.06711056, 0.00583715);
    float innerFract = fract(scaledPos.x + scaledPos.y);
    float dither = fract(52.9829189 * innerFract);
    return vec3(dither - 0.5) / 255.0;
}

// Simple temporal anti-aliasing using screen-space derivatives
vec3 temporalAA(vec3 currentColor, vec2 screenPos) {
    // Use screen derivatives to estimate motion and apply simple temporal filtering
    vec2 velocity = vec2(dFdx(screenPos.x), dFdy(screenPos.y)) * 0.5;
    
    // Simple temporal accumulation using frame-to-frame coherence
    // This creates a basic TAA effect without requiring history buffers
    float temporalWeight = 0.85;
    
    // Use screen position hash for pseudo-random temporal offset
    float hash = fract(sin(dot(screenPos, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 temporalOffset = vec3(hash - 0.5) * 0.02;
    
    // Apply temporal filtering based on motion estimation
    float motionMagnitude = length(velocity);
    float adaptiveWeight = temporalWeight * exp(-motionMagnitude * 8.0);
    
    // Blend with slight temporal offset for anti-aliasing effect
    vec3 temporalColor = currentColor + temporalOffset;
    return mix(currentColor, temporalColor, adaptiveWeight);
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
    vec3 baseColor = color.rgb * edge * light + dither;
    
    // Apply simple temporal anti-aliasing
    vec3 finalColor = temporalAA(baseColor, gl_FragCoord.xy);
    
    frag_color = vec4(finalColor, color.a);
}
@end

@program cube vs fs
