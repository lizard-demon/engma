const std = @import("std");

pub const Vec2 = struct {
    v: @Vector(2, f32),

    pub fn new(x: f32, y: f32) Vec2 {
        return .{ .v = .{ x, y } };
    }

    pub fn zero() Vec2 {
        return .{ .v = @splat(0) };
    }
};

pub const Vec3 = struct {
    v: @Vector(3, f32),

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return .{ .v = .{ x, y, z } };
    }

    pub fn zero() Vec3 {
        return .{ .v = @splat(0) };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .v = a.v + b.v };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .v = a.v - b.v };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .v = v.v * @as(@Vector(3, f32), @splat(s)) };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return @reduce(.Add, a.v * b.v);
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{ .v = .{
            a.v[1] * b.v[2] - a.v[2] * b.v[1],
            a.v[2] * b.v[0] - a.v[0] * b.v[2],
            a.v[0] * b.v[1] - a.v[1] * b.v[0],
        } };
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(dot(v, v));
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = length(v);
        return if (len > std.math.floatEps(f32)) scale(v, 1.0 / len) else zero();
    }
};

pub const Mat4 = struct {
    m: [16]f32,

    pub fn identity() Mat4 {
        return .{ .m = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        } };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;
        inline for (0..4) |col| {
            inline for (0..4) |row| {
                var sum: f32 = 0;
                inline for (0..4) |k| {
                    sum += a.m[k * 4 + row] * b.m[col * 4 + k];
                }
                result.m[col * 4 + row] = sum;
            }
        }
        return result;
    }
};

pub const Vertex = struct {
    pos: [3]f32,
    col: [4]f32,
};

pub const Mesh = struct {
    vertices: []const Vertex,
    indices: []const u16,
};

pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat4 {
    const f = 1.0 / @tan(fov_y * 0.5);
    const range_inv = 1.0 / (near - far);

    return .{ .m = .{
        f / aspect, 0, 0,                            0,
        0,          f, 0,                            0,
        0,          0, (far + near) * range_inv,     -1,
        0,          0, 2.0 * far * near * range_inv, 0,
    } };
}
