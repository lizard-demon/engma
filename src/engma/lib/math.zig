// Pure math - SIMD vectors and matrices with modern Zig 0.15.1 features
const std = @import("std");

pub const Vec = struct {
    data: @Vector(3, f32),

    pub inline fn new(x: f32, y: f32, z: f32) Vec {
        return .{ .data = .{ x, y, z } };
    }

    pub inline fn zero() Vec {
        return .{ .data = @splat(0.0) };
    }

    pub inline fn add(a: Vec, b: Vec) Vec {
        return .{ .data = a.data + b.data };
    }

    pub inline fn sub(a: Vec, b: Vec) Vec {
        return .{ .data = a.data - b.data };
    }

    pub inline fn scale(v: Vec, s: f32) Vec {
        return .{ .data = v.data * @as(@Vector(3, f32), @splat(s)) };
    }

    pub inline fn dot(a: Vec, b: Vec) f32 {
        return @reduce(.Add, a.data * b.data);
    }

    pub inline fn len(v: Vec) f32 {
        return @sqrt(v.dot(v));
    }

    pub inline fn norm(v: Vec) Vec {
        const l = v.len();
        return if (l > std.math.floatEps(f32)) v.scale(1.0 / l) else v;
    }

    pub inline fn cross(a: Vec, b: Vec) Vec {
        return .{ .data = .{
            a.data[1] * b.data[2] - a.data[2] * b.data[1],
            a.data[2] * b.data[0] - a.data[0] * b.data[2],
            a.data[0] * b.data[1] - a.data[1] * b.data[0],
        } };
    }
};

pub const Mat = struct {
    data: [16]f32,

    pub inline fn identity() Mat {
        return .{ .data = .{
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        } };
    }

    pub inline fn mul(a: Mat, b: Mat) Mat {
        var r: Mat = undefined;
        inline for (0..4) |c| inline for (0..4) |row| {
            var s: f32 = 0.0;
            inline for (0..4) |k| s += a.data[k * 4 + row] * b.data[c * 4 + k];
            r.data[c * 4 + row] = s;
        };
        return r;
    }

    pub inline fn transpose(m: Mat) Mat {
        var r: Mat = undefined;
        inline for (0..4) |i| inline for (0..4) |j| {
            r.data[j * 4 + i] = m.data[i * 4 + j];
        };
        return r;
    }
};

// Modern Zig 0.15.1 compatible matrix type for shaders
pub const Mat4 = extern struct {
    data: [16]f32 align(16),

    pub inline fn fromMat(m: Mat) Mat4 {
        return .{ .data = m.data };
    }
};

pub const Box = struct { min: Vec, max: Vec };

// Mesh types for generic rendering
pub const Vertex = extern struct { pos: [3]f32, col: [4]f32 };

pub const Mesh = struct {
    vertices: []const Vertex,
    indices: []const u16,
};

pub inline fn proj(fov: f32, asp: f32, n: f32, f: f32) Mat {
    const t = @tan(fov * std.math.pi / 360.0) * n;
    const r = t * asp;
    return .{ .data = .{ n / r, 0.0, 0.0, 0.0, 0.0, n / t, 0.0, 0.0, 0.0, 0.0, -(f + n) / (f - n), -1.0, 0.0, 0.0, -(2.0 * f * n) / (f - n), 0.0 } };
}

// Modern perspective projection with better numerical stability
pub inline fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat {
    const f = 1.0 / @tan(fov_y * 0.5);
    const nf = 1.0 / (near - far);

    return .{ .data = .{
        f / aspect, 0.0, 0.0,                   0.0,
        0.0,        f,   0.0,                   0.0,
        0.0,        0.0, (far + near) * nf,     -1.0,
        0.0,        0.0, 2.0 * far * near * nf, 0.0,
    } };
}
