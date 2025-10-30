// Bitpacked voxel world - 4096 voxels in 512 bytes
const math = @import("../lib/math.zig");

const SIZE = 16;

pub const World = struct {
    bits: [SIZE * SIZE * SIZE / 8]u8,

    pub fn init() World {
        var w = World{ .bits = [_]u8{0} ** (SIZE * SIZE * SIZE / 8) };

        // Procedural world: floor + walls + pillars
        for (0..SIZE) |x| for (0..SIZE) |y| for (0..SIZE) |z| {
            if (y == 0 or x == 0 or x == SIZE - 1 or z == 0 or z == SIZE - 1 or
                (x % 4 == 0 and z % 4 == 0 and y < 3))
            {
                const i = x + y * SIZE + z * SIZE * SIZE;
                w.bits[i >> 3] |= @as(u8, 1) << @intCast(i & 7);
            }
        };
        return w;
    }

    pub fn get(self: *const World, x: i32, y: i32, z: i32) bool {
        if (@as(u32, @bitCast(x | y | z)) >= SIZE) return false;
        const i = @as(u32, @intCast(x)) + @as(u32, @intCast(y)) * SIZE + @as(u32, @intCast(z)) * SIZE * SIZE;
        return (self.bits[i >> 3] >> @intCast(i & 7)) & 1 != 0;
    }

    pub fn mesh(self: *const World, vertices: []math.Vertex, indices: []u16) math.Mesh {
        var vc: usize = 0;
        var ic: usize = 0;

        // Face dirs, quads, colors
        const dirs = [_][3]i32{ .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, -1, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 } };
        const quads = [_][4][3]f32{ .{ .{ 1, 0, 0 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 } }, .{ .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 1 } }, .{ .{ 0, 1, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } }, .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 0, 0 }, .{ 0, 0, 0 } }, .{ .{ 1, 0, 1 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 1, 1, 1 } }, .{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 0, 1, 0 } } };
        const cols = [_][4]f32{ .{ 0.8, 0.3, 0.3, 1 }, .{ 0.3, 0.8, 0.3, 1 }, .{ 0.6, 0.6, 0.6, 1 }, .{ 0.4, 0.4, 0.4, 1 }, .{ 0.3, 0.3, 0.8, 1 }, .{ 0.8, 0.8, 0.3, 1 } };

        // Generate faces for each voxel
        for (0..SIZE) |x| for (0..SIZE) |y| for (0..SIZE) |z| {
            if (!self.get(@intCast(x), @intCast(y), @intCast(z))) continue;
            const pos = @Vector(3, f32){ @floatFromInt(x), @floatFromInt(y), @floatFromInt(z) };

            for (dirs, quads, cols) |dir, quad, col| {
                if (!self.get(@as(i32, @intCast(x)) + dir[0], @as(i32, @intCast(y)) + dir[1], @as(i32, @intCast(z)) + dir[2])) {
                    if (vc + 4 > vertices.len or ic + 6 > indices.len) break;
                    const base = @as(u16, @intCast(vc));

                    for (quad) |v| {
                        vertices[vc] = .{ .pos = pos + v, .col = col };
                        vc += 1;
                    }
                    for ([_]u16{ 0, 1, 2, 0, 2, 3 }) |i| {
                        indices[ic] = base + i;
                        ic += 1;
                    }
                }
            }
        };

        return .{ .vertices = vertices[0..vc], .indices = indices[0..ic] };
    }
};
