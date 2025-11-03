const std = @import("std");
const math = @import("../lib/math.zig");

const SIZE = 64;
const BITS_PER_U64 = 64;
const CHUNKS_PER_LAYER = (SIZE * SIZE + BITS_PER_U64 - 1) / BITS_PER_U64;

pub const World = struct {
    data: [SIZE][CHUNKS_PER_LAYER]u64,

    pub fn init(allocator: std.mem.Allocator) World {
        var w = World{ .data = [_][CHUNKS_PER_LAYER]u64{[_]u64{0} ** CHUNKS_PER_LAYER} ** SIZE };
        w.load(allocator, "map.dat") catch {
            for (0..SIZE) |x| for (0..SIZE) |y| for (0..SIZE) |z| {
                const is_wall = x == 0 or x == SIZE - 1 or z == 0 or z == SIZE - 1;
                const is_floor = y == 0;
                if ((is_wall and y <= 2) or is_floor) {
                    const idx = y * SIZE + z;
                    const chunk_idx = idx / BITS_PER_U64;
                    const bit_idx: u6 = @intCast(idx % BITS_PER_U64);
                    w.data[x][chunk_idx] |= @as(u64, 1) << bit_idx;
                }
            };
        };
        return w;
    }

    pub fn deinit(self: *const World, allocator: std.mem.Allocator, _: anytype) void {
        self.save(allocator, "map.dat") catch {};
    }

    pub fn tick(_: *World, _: std.mem.Allocator, _: anytype) void {}
    pub fn draw(_: *World, _: std.mem.Allocator, _: anytype) void {}
    pub fn event(_: *World, _: std.mem.Allocator, _: anytype, _: anytype) void {}

    inline fn getBit(self: *const World, x: u32, y: u32, z: u32) bool {
        const idx = y * SIZE + z;
        const chunk_idx = idx / BITS_PER_U64;
        const bit_idx: u6 = @intCast(idx % BITS_PER_U64);
        return (self.data[x][chunk_idx] & (@as(u64, 1) << bit_idx)) != 0;
    }

    pub fn get(self: *const World, x: i32, y: i32, z: i32) bool {
        if (x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE) return false;
        return self.getBit(@intCast(x), @intCast(y), @intCast(z));
    }

    pub fn save(self: *const World, _: std.mem.Allocator, path: []const u8) !void {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| return err;
        defer file.close();
        file.writeAll(std.mem.asBytes(&self.data)) catch |err| return err;
    }

    pub fn load(self: *World, _: std.mem.Allocator, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer file.close();
        _ = file.readAll(std.mem.asBytes(&self.data)) catch |err| return err;
    }

    pub fn mesh(self: *const World, vertices: []math.Vertex, indices: []u16) math.Mesh {
        var vi: usize = 0;
        var ii: usize = 0;
        var mask: [SIZE * SIZE]FaceInfo = undefined;
        const shades = [_]f32{ 0.8, 0.8, 0.6, 0.8, 1.0, 1.0 };

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

const FaceInfo = struct { block: bool, is_back: bool };

fn buildFaceMask(w: *const World, mask: *[SIZE * SIZE]FaceInfo, axis: usize, u: usize, v: usize, d: i32) void {
    @memset(mask, .{ .block = false, .is_back = false });

    for (0..SIZE) |j| for (0..SIZE) |i| {
        var pos1 = [3]i32{ 0, 0, 0 };
        var pos2 = [3]i32{ 0, 0, 0 };
        pos1[axis] = d - 1;
        pos2[axis] = d;
        pos1[u] = @intCast(i);
        pos1[v] = @intCast(j);
        pos2[u] = @intCast(i);
        pos2[v] = @intCast(j);

        const b1 = w.get(pos1[0], pos1[1], pos1[2]);
        const b2 = w.get(pos2[0], pos2[1], pos2[2]);

        if (b1 and !b2) {
            mask[j * SIZE + i] = .{ .block = true, .is_back = false };
        } else if (!b1 and b2) {
            mask[j * SIZE + i] = .{ .block = true, .is_back = true };
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
            if (!face_info.block) {
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
        if (!next_face.block or next_face.is_back != face_info.is_back) break;
        width += 1;
    }

    var height: usize = 1;
    while (start_j + height < SIZE) {
        var row_matches = true;
        for (0..width) |k| {
            const check_face = mask[(start_j + height) * SIZE + start_i + k];
            if (!check_face.block or check_face.is_back != face_info.is_back) {
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
        mask[(start_j + h) * SIZE + start_i + w_idx] = .{ .block = false, .is_back = false };
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
    const shade_offset: usize = if (face_info.is_back) 0 else 1;
    const shade_idx = axis * 2 + shade_offset;
    const shade = shades[shade_idx];
    const fcol = [4]f32{ shade, shade, shade, 1.0 };

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
