// 64x64x64 greedy meshed world - adapted from duel
const std = @import("std");
const math = @import("../lib/math.zig");

const SIZE = 64;
pub const Block = u8;

// HSV to RGB conversion for block colors
inline fn hsvToRgb(h: f32, s: f32, v: f32) [3]f32 {
    const c = v * s;
    const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
    const m = v - c;
    const rgb = if (h < 60.0) [3]f32{ c, x, 0 } else if (h < 120.0) [3]f32{ x, c, 0 } else if (h < 180.0) [3]f32{ 0, c, x } else if (h < 240.0) [3]f32{ 0, x, c } else if (h < 300.0) [3]f32{ x, 0, c } else [3]f32{ c, 0, x };
    return .{ rgb[0] + m, rgb[1] + m, rgb[2] + m };
}

fn blockColor(block: Block) [3]f32 {
    if (block == 0) return .{ 0, 0, 0 }; // air
    if (block == 1) return .{ 0, 0, 0 }; // black
    if (block == 2) return .{ 1, 1, 1 }; // white

    // Bit-packed HSV: 32 hues, 4 saturations, 2 values
    const hue = @as(f32, @floatFromInt(block & 0x1F)) * 360.0 / 32.0;
    const sat = 0.25 + @as(f32, @floatFromInt((block >> 5) & 0x03)) * 0.25;
    const val = 0.4 + @as(f32, @floatFromInt((block >> 7) & 0x01)) * 0.6;
    return hsvToRgb(hue, sat, val);
}

pub const World = struct {
    blocks: [SIZE][SIZE][SIZE]Block,

    pub fn init(allocator: std.mem.Allocator) World {
        var w = World{ .blocks = [_][SIZE][SIZE]Block{[_][SIZE]Block{[_]Block{0} ** SIZE} ** SIZE} ** SIZE };

        // Try to load map.dat, fallback to default world if it doesn't exist
        w.load(allocator, "map.dat") catch {
            // Generate simple world: floor + walls
            for (0..SIZE) |x| for (0..SIZE) |y| for (0..SIZE) |z| {
                const is_wall = x == 0 or x == SIZE - 1 or z == 0 or z == SIZE - 1;
                const is_floor = y == 0;
                w.blocks[x][y][z] = if ((is_wall and y <= 2) or is_floor) 2 else 0;
            };
        };
        return w;
    }

    pub fn deinit(self: *const World, allocator: std.mem.Allocator) void {
        self.save(allocator, "map.dat") catch {};
    }

    pub fn get(self: *const World, x: i32, y: i32, z: i32) bool {
        if (x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE) return false;
        return self.blocks[@intCast(x)][@intCast(y)][@intCast(z)] != 0;
    }

    fn getBlock(self: *const World, x: i32, y: i32, z: i32) Block {
        if (x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE) return 0;
        return self.blocks[@intCast(x)][@intCast(y)][@intCast(z)];
    }

    pub fn set(self: *World, x: i32, y: i32, z: i32, block: Block) bool {
        if (x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE) return false;
        const old_block = self.blocks[@intCast(x)][@intCast(y)][@intCast(z)];
        if (old_block == block) return false;
        self.blocks[@intCast(x)][@intCast(y)][@intCast(z)] = block;
        return true;
    }

    // Binary RLE save
    pub fn save(self: *const World, allocator: std.mem.Allocator, path: []const u8) !void {
        const compressed = try allocator.alloc(u8, SIZE * SIZE * SIZE * 2);
        defer allocator.free(compressed);

        var write_pos: usize = 0;
        var current_block = self.blocks[0][0][0];
        var run_length: u8 = 1;

        for (0..SIZE) |x| {
            for (0..SIZE) |y| {
                for (0..SIZE) |z| {
                    if (x == 0 and y == 0 and z == 0) continue;

                    const block = self.blocks[x][y][z];
                    if (block == current_block and run_length < 255) {
                        run_length += 1;
                    } else {
                        compressed[write_pos] = run_length;
                        compressed[write_pos + 1] = current_block;
                        write_pos += 2;
                        current_block = block;
                        run_length = 1;
                    }
                }
            }
        }

        compressed[write_pos] = run_length;
        compressed[write_pos + 1] = current_block;
        write_pos += 2;

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(compressed[0..write_pos]);
    }

    // Binary RLE load
    pub fn load(self: *World, allocator: std.mem.Allocator, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch return;
        defer file.close();

        const data = try file.readToEndAlloc(allocator, SIZE * SIZE * SIZE * 2);
        defer allocator.free(data);

        self.blocks = [_][SIZE][SIZE]Block{[_][SIZE]Block{[_]Block{0} ** SIZE} ** SIZE} ** SIZE;

        var read_pos: usize = 0;
        var block_pos: usize = 0;

        while (read_pos + 1 < data.len and block_pos < SIZE * SIZE * SIZE) {
            const run_length = data[read_pos];
            const block_value = data[read_pos + 1];
            read_pos += 2;

            for (0..run_length) |_| {
                if (block_pos >= SIZE * SIZE * SIZE) break;
                const x = block_pos / (SIZE * SIZE);
                const y = (block_pos % (SIZE * SIZE)) / SIZE;
                const z = block_pos % SIZE;
                self.blocks[x][y][z] = block_value;
                block_pos += 1;
            }
        }
    }

    pub fn mesh(self: *const World, vertices: []math.Vertex, indices: []u16) math.Mesh {
        var vi: usize = 0;
        var ii: usize = 0;
        var mask: [SIZE * SIZE]FaceInfo = undefined;
        const shades = [_]f32{ 0.8, 0.8, 0.6, 0.8, 1.0, 1.0 };

        // Greedy meshing - sweep each axis
        inline for (0..3) |axis| {
            const u = (axis + 1) % 3;
            const v = (axis + 2) % 3;

            var d: i32 = 0;
            while (d < SIZE) : (d += 1) {
                buildFaceMask(self, &mask, axis, u, v, d);
                generateQuads(&mask, &vi, &ii, vertices, indices, axis, u, v, d, shades);
            }
        }
        return .{ .vertices = vertices[0..vi], .indices = indices[0..ii] };
    }
};

const FaceInfo = struct { block: Block, is_back: bool };

fn buildFaceMask(w: *const World, mask: *[SIZE * SIZE]FaceInfo, axis: usize, u: usize, v: usize, d: i32) void {
    @memset(mask, .{ .block = 0, .is_back = false });

    for (0..SIZE) |j| for (0..SIZE) |i| {
        var pos1 = [3]i32{ 0, 0, 0 };
        var pos2 = [3]i32{ 0, 0, 0 };
        pos1[axis] = d - 1;
        pos2[axis] = d;
        pos1[u] = @intCast(i);
        pos1[v] = @intCast(j);
        pos2[u] = @intCast(i);
        pos2[v] = @intCast(j);

        const b1 = w.getBlock(pos1[0], pos1[1], pos1[2]);
        const b2 = w.getBlock(pos2[0], pos2[1], pos2[2]);

        if (b1 != 0 and b2 == 0) {
            mask[j * SIZE + i] = .{ .block = b1, .is_back = false };
        } else if (b1 == 0 and b2 != 0) {
            mask[j * SIZE + i] = .{ .block = b2, .is_back = true };
        }
    };
}

fn generateQuads(
    mask: *[SIZE * SIZE]FaceInfo,
    vi: *usize,
    ii: *usize,
    vertices: []math.Vertex,
    indices: []u16,
    axis: usize,
    u: usize,
    v: usize,
    d: i32,
    shades: [6]f32,
) void {
    var j: usize = 0;
    while (j < SIZE) : (j += 1) {
        var i: usize = 0;
        while (i < SIZE) {
            const face_info = mask[j * SIZE + i];
            if (face_info.block == 0) {
                i += 1;
                continue;
            }

            const quad_size = findQuadSize(mask, face_info, i, j);
            clearMaskArea(mask, i, j, quad_size.width, quad_size.height);

            if (vi.* + 4 > vertices.len or ii.* + 6 > indices.len) return;

            buildQuad(vertices, indices, vi, ii, face_info, axis, u, v, d, i, j, quad_size.width, quad_size.height, shades);
            i += quad_size.width;
        }
    }
}

fn findQuadSize(mask: *[SIZE * SIZE]FaceInfo, face_info: FaceInfo, start_i: usize, start_j: usize) struct { width: usize, height: usize } {
    var width: usize = 1;
    while (start_i + width < SIZE) {
        const next_face = mask[start_j * SIZE + start_i + width];
        if (next_face.block != face_info.block or next_face.is_back != face_info.is_back) break;
        width += 1;
    }

    var height: usize = 1;
    while (start_j + height < SIZE) {
        var row_matches = true;
        for (0..width) |k| {
            const check_face = mask[(start_j + height) * SIZE + start_i + k];
            if (check_face.block != face_info.block or check_face.is_back != face_info.is_back) {
                row_matches = false;
                break;
            }
        }
        if (!row_matches) break;
        height += 1;
    }

    return .{ .width = width, .height = height };
}

fn clearMaskArea(mask: *[SIZE * SIZE]FaceInfo, start_i: usize, start_j: usize, width: usize, height: usize) void {
    for (0..height) |h| for (0..width) |w_idx| {
        mask[(start_j + h) * SIZE + start_i + w_idx] = .{ .block = 0, .is_back = false };
    };
}

fn buildQuad(
    vertices: []math.Vertex,
    indices: []u16,
    vi: *usize,
    ii: *usize,
    face_info: FaceInfo,
    axis: usize,
    u: usize,
    v: usize,
    d: i32,
    start_i: usize,
    start_j: usize,
    width: usize,
    height: usize,
    shades: [6]f32,
) void {
    const col = blockColor(face_info.block);
    const shade_offset: usize = if (face_info.is_back) 0 else 1;
    const shade_idx = axis * 2 + shade_offset;
    const shade = shades[shade_idx];
    const fcol = [4]f32{ col[0] * shade, col[1] * shade, col[2] * shade, 1 };

    const face_pos: f32 = @floatFromInt(d);
    var quad = [4][3]f32{ .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } };

    quad[0][axis] = face_pos;
    quad[0][u] = @floatFromInt(start_i);
    quad[0][v] = @floatFromInt(start_j);

    quad[1][axis] = face_pos;
    quad[1][u] = @floatFromInt(start_i);
    quad[1][v] = @floatFromInt(start_j + height);

    quad[2][axis] = face_pos;
    quad[2][u] = @floatFromInt(start_i + width);
    quad[2][v] = @floatFromInt(start_j + height);

    quad[3][axis] = face_pos;
    quad[3][u] = @floatFromInt(start_i + width);
    quad[3][v] = @floatFromInt(start_j);

    const base = @as(u16, @intCast(vi.*));

    if (face_info.is_back) {
        vertices[vi.*] = .{ .pos = quad[0], .col = fcol };
        vertices[vi.* + 1] = .{ .pos = quad[3], .col = fcol };
        vertices[vi.* + 2] = .{ .pos = quad[2], .col = fcol };
        vertices[vi.* + 3] = .{ .pos = quad[1], .col = fcol };
    } else {
        vertices[vi.*] = .{ .pos = quad[0], .col = fcol };
        vertices[vi.* + 1] = .{ .pos = quad[1], .col = fcol };
        vertices[vi.* + 2] = .{ .pos = quad[2], .col = fcol };
        vertices[vi.* + 3] = .{ .pos = quad[3], .col = fcol };
    }
    vi.* += 4;

    for ([_]u16{ 0, 1, 2, 0, 2, 3 }) |idx| {
        indices[ii.*] = base + idx;
        ii.* += 1;
    }
}
