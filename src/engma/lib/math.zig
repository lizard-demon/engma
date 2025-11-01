const std = @import("std");
const math = std.math;

pub const Vec3 = struct {
    v: @Vector(3, f32),

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .v = .{ x, y, z } };
    }

    pub fn zero() Vec3 {
        return .{ .v = @splat(0.0) };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .v = a.v + b.v };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .v = a.v - b.v };
    }

    pub fn mul(a: Vec3, b: Vec3) Vec3 {
        return .{ .v = a.v * b.v };
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
        return @sqrt(v.dot(v));
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = v.length();
        return if (len > math.floatEps(f32)) v.scale(1.0 / len) else Vec3.zero();
    }
};

pub const Mat4 = struct {
    m: [16]f32,

    pub fn identity() Mat4 {
        return .{ .m = .{
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        } };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;
        inline for (0..4) |col| {
            inline for (0..4) |row| {
                var sum: f32 = 0.0;
                inline for (0..4) |k| {
                    sum += a.m[k * 4 + row] * b.m[col * 4 + k];
                }
                result.m[col * 4 + row] = sum;
            }
        }
        return result;
    }

    pub fn translate(v: Vec3) Mat4 {
        var m = Mat4.identity();
        m.m[12] = v.v[0];
        m.m[13] = v.v[1];
        m.m[14] = v.v[2];
        return m;
    }

    pub fn scale(v: Vec3) Mat4 {
        var m = Mat4.identity();
        m.m[0] = v.v[0];
        m.m[5] = v.v[1];
        m.m[10] = v.v[2];
        return m;
    }
};

pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat4 {
    const f = 1.0 / @tan(fov_y * 0.5);
    const range_inv = 1.0 / (near - far);

    var m = Mat4{ .m = std.mem.zeroes([16]f32) };
    m.m[0] = f / aspect;
    m.m[5] = f;
    m.m[10] = (far + near) * range_inv;
    m.m[11] = -1.0;
    m.m[14] = 2.0 * far * near * range_inv;

    return m;
}
