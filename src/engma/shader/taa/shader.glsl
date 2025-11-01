@header const math = @import("../../lib/math.zig")
@ctype mat4 math.Mat4
@ctype vec2 math.Vec2

@vs vs
in vec2 position;
out vec2 uv;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    uv = position * 0.5 + 0.5;
}
@end

@fs fs
layout(binding = 0) uniform sampler2D current_frame;
layout(binding = 1) uniform sampler2D history_frame;
layout(binding = 2) uniform sampler2D velocity_buffer;
layout(binding = 3) uniform sampler2D depth_buffer;

layout(binding = 0) uniform fs_params {
    vec2 jitter_offset;
    float feedback_min;
    float feedback_max;
    float motion_amplification;
    float variance_gamma;
};

in vec2 uv;
out vec4 frag_color;

// Optimized RGB to YCoCg conversion for better temporal stability
vec3 RGBToYCoCg(vec3 rgb) {
    float Y = dot(rgb, vec3(0.25, 0.5, 0.25));
    float Co = dot(rgb, vec3(0.5, 0.0, -0.5));
    float Cg = dot(rgb, vec3(-0.25, 0.5, -0.25));
    return vec3(Y, Co, Cg);
}

vec3 YCoCgToRGB(vec3 ycocg) {
    float Y = ycocg.x;
    float Co = ycocg.y;
    float Cg = ycocg.z;
    float tmp = Y - Cg;
    return vec3(tmp + Co, Y + Cg, tmp - Co);
}

// Variance-based neighborhood clamping (Karis 2014)
vec3 clipAABB(vec3 aabbMin, vec3 aabbMax, vec3 prevSample, float gamma) {
    vec3 center = 0.5 * (aabbMax + aabbMin);
    vec3 extents = 0.5 * (aabbMax - aabbMin) + 0.001;
    
    vec3 offset = prevSample - center;
    vec3 v_unit = offset / extents;
    vec3 a_unit = abs(v_unit);
    float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));
    
    if (ma_unit > 1.0) {
        return center + (offset / ma_unit);
    }
    
    // Variance clipping with gamma correction
    vec3 clipped = center + offset * pow(1.0 - ma_unit, gamma);
    return clipped;
}

// Catmull-Rom filtering for better history sampling
vec3 sampleCatmullRom(sampler2D tex, vec2 uv, vec2 texSize) {
    vec2 samplePos = uv * texSize;
    vec2 texPos1 = floor(samplePos - 0.5) + 0.5;
    vec2 f = samplePos - texPos1;
    
    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);
    
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / (w1 + w2);
    
    vec2 texPos0 = texPos1 - 1.0;
    vec2 texPos3 = texPos1 + 2.0;
    vec2 texPos12 = texPos1 + offset12;
    
    texPos0 /= texSize;
    texPos3 /= texSize;
    texPos12 /= texSize;
    
    vec3 result = texture(tex, vec2(texPos0.x, texPos0.y)).rgb * w0.x * w0.y;
    result += texture(tex, vec2(texPos12.x, texPos0.y)).rgb * w12.x * w0.y;
    result += texture(tex, vec2(texPos3.x, texPos0.y)).rgb * w3.x * w0.y;
    
    result += texture(tex, vec2(texPos0.x, texPos12.y)).rgb * w0.x * w12.y;
    result += texture(tex, vec2(texPos12.x, texPos12.y)).rgb * w12.x * w12.y;
    result += texture(tex, vec2(texPos3.x, texPos12.y)).rgb * w3.x * w12.y;
    
    result += texture(tex, vec2(texPos0.x, texPos3.y)).rgb * w0.x * w3.y;
    result += texture(tex, vec2(texPos12.x, texPos3.y)).rgb * w12.x * w3.y;
    result += texture(tex, vec2(texPos3.x, texPos3.y)).rgb * w3.x * w3.y;
    
    return max(result, 0.0);
}

void main() {
    vec2 texelSize = 1.0 / textureSize(current_frame, 0);
    
    // Sample current frame and convert to YCoCg
    vec3 current = texture(current_frame, uv).rgb;
    vec3 currentYCoCg = RGBToYCoCg(current);
    
    // Sample velocity and compute reprojected UV
    vec2 velocity = texture(velocity_buffer, uv).xy;
    vec2 historyUV = uv - velocity;
    
    // Check if history sample is valid (within screen bounds)
    bool validHistory = all(greaterThanEqual(historyUV, vec2(0.0))) && 
                       all(lessThanEqual(historyUV, vec2(1.0)));
    
    // Sample history with high-quality filtering
    vec3 history = validHistory ? 
        sampleCatmullRom(history_frame, historyUV, 1.0 / texelSize) :
        current;
    vec3 historyYCoCg = RGBToYCoCg(history);
    
    // Optimized 3x3 neighborhood sampling with cross pattern for performance
    vec3 colorMin = currentYCoCg;
    vec3 colorMax = currentYCoCg;
    vec3 colorAvg = currentYCoCg;
    vec3 colorVar = currentYCoCg * currentYCoCg;
    
    // Cross pattern sampling (5 samples instead of 9)
    const vec2 offsets[4] = vec2[4](
        vec2(-1.0, 0.0), vec2(1.0, 0.0),
        vec2(0.0, -1.0), vec2(0.0, 1.0)
    );
    
    for (int i = 0; i < 4; i++) {
        vec2 sampleUV = uv + offsets[i] * texelSize;
        vec3 neighbor = RGBToYCoCg(texture(current_frame, sampleUV).rgb);
        
        colorMin = min(colorMin, neighbor);
        colorMax = max(colorMax, neighbor);
        colorAvg += neighbor;
        colorVar += neighbor * neighbor;
    }
    
    colorAvg /= 5.0;
    colorVar = colorVar / 5.0 - colorAvg * colorAvg;
    
    // Variance-based clipping
    vec3 sigma = sqrt(max(colorVar, 0.0));
    vec3 colorMin2 = colorAvg - variance_gamma * sigma;
    vec3 colorMax2 = colorAvg + variance_gamma * sigma;
    
    colorMin = max(colorMin, colorMin2);
    colorMax = min(colorMax, colorMax2);
    
    // Clip history to neighborhood
    historyYCoCg = clipAABB(colorMin, colorMax, historyYCoCg, variance_gamma);
    
    // Compute confidence based on multiple factors
    float velocityLength = length(velocity * motion_amplification);
    float velocityConfidence = exp(-velocityLength);
    
    // Luminance difference confidence
    float lumaDiff = abs(currentYCoCg.x - historyYCoCg.x);
    float lumaConfidence = exp(-lumaDiff * 8.0);
    
    // Depth-based confidence (if depth buffer available)
    float depthConfidence = 1.0;
    if (validHistory) {
        float currentDepth = texture(depth_buffer, uv).r;
        float historyDepth = texture(depth_buffer, historyUV).r;
        float depthDiff = abs(currentDepth - historyDepth);
        depthConfidence = exp(-depthDiff * 100.0);
    }
    
    // Combined confidence
    float confidence = velocityConfidence * lumaConfidence * depthConfidence;
    confidence = validHistory ? confidence : 0.0;
    
    // Adaptive feedback factor
    float feedback = mix(feedback_min, feedback_max, confidence);
    
    // Temporal accumulation in YCoCg space
    vec3 resultYCoCg = mix(currentYCoCg, historyYCoCg, feedback);
    
    // Convert back to RGB
    vec3 result = YCoCgToRGB(resultYCoCg);
    
    frag_color = vec4(result, 1.0);
}
@end

@program taa vs fs