// Empty world implementation - for testing the module system
const std = @import("std");
const math = @import("../lib/math.zig");

pub const World = struct {
    pub fn init() World {
        return .{};
    }

    pub fn get(self: *const World, x: i32, y: i32, z: i32) bool {
        _ = self;
        // Only floor exists
        return y == 0 and x >= -10 and x <= 10 and z >= -10 and z <= 10;
    }

    pub fn mesh(self: *const World, vertices: []math.Vertex, indices: []u16) math.Mesh {
        _ = self;
        var vc: usize = 0;
        var ic: usize = 0;

        // Simple floor quad
        const floor_color = [4]f32{ 0.5, 0.5, 0.5, 1.0 };
        const floor_verts = [_][3]f32{ .{ -10, 0, -10 }, .{ 10, 0, -10 }, .{ 10, 0, 10 }, .{ -10, 0, 10 } };

        if (vertices.len >= 4 and indices.len >= 6) {
            for (floor_verts) |v| {
                vertices[vc] = .{ .pos = v, .col = floor_color };
                vc += 1;
            }
            for ([_]u16{ 0, 1, 2, 0, 2, 3 }) |i| {
                indices[ic] = i;
                ic += 1;
            }
        }

        return .{ .vertices = vertices[0..vc], .indices = indices[0..ic] };
    }
};
