const std = @import("std");
const math = @import("../../lib/math.zig");

const Vec3 = math.Vec3;

pub const BBox = struct {
    min: Vec3,
    max: Vec3,

    pub fn at(self: BBox, pos: Vec3) BBox {
        return .{ .min = Vec3.add(pos, self.min), .max = Vec3.add(pos, self.max) };
    }

    pub fn bounds(self: BBox, vel: Vec3) struct { min: Vec3, max: Vec3 } {
        const sm = Vec3.add(self.min, vel);
        const sx = Vec3.add(self.max, vel);
        return .{
            .min = Vec3.new(@min(sm.v[0], self.min.v[0]), @min(sm.v[1], self.min.v[1]), @min(sm.v[2], self.min.v[2])),
            .max = Vec3.new(@max(sx.v[0], self.max.v[0]), @max(sx.v[1], self.max.v[1]), @max(sx.v[2], self.max.v[2])),
        };
    }

    pub fn sweep(self: BBox, vel: Vec3, other: BBox) ?struct { t: f32, n: Vec3 } {
        if (@sqrt(Vec3.dot(vel, vel)) < 0.0001) return null;

        const inv = Vec3.new(
            if (vel.v[0] != 0) 1 / vel.v[0] else std.math.inf(f32),
            if (vel.v[1] != 0) 1 / vel.v[1] else std.math.inf(f32),
            if (vel.v[2] != 0) 1 / vel.v[2] else std.math.inf(f32),
        );

        const tx = axis(self.min.v[0], self.max.v[0], other.min.v[0], other.max.v[0], inv.v[0]);
        const ty = axis(self.min.v[1], self.max.v[1], other.min.v[1], other.max.v[1], inv.v[1]);
        const tz = axis(self.min.v[2], self.max.v[2], other.min.v[2], other.max.v[2], inv.v[2]);

        const enter = @max(@max(tx.enter, ty.enter), tz.enter);
        const exit = @min(@min(tx.exit, ty.exit), tz.exit);

        if (enter > exit or enter > 1 or exit < 0 or enter < 0) return null;

        const n = if (tx.enter > ty.enter and tx.enter > tz.enter)
            Vec3.new(if (vel.v[0] > 0) -1 else 1, 0, 0)
        else if (ty.enter > tz.enter)
            Vec3.new(0, if (vel.v[1] > 0) -1 else 1, 0)
        else
            Vec3.new(0, 0, if (vel.v[2] > 0) -1 else 1);

        return .{ .t = enter, .n = n };
    }

    fn axis(min1: f32, max1: f32, min2: f32, max2: f32, inv: f32) struct { enter: f32, exit: f32 } {
        const t1 = (min2 - max1) * inv;
        const t2 = (max2 - min1) * inv;
        return .{ .enter = @min(t1, t2), .exit = @max(t1, t2) };
    }
};

pub fn sweep(world: anytype, pos: Vec3, box: BBox, vel: Vec3, comptime steps: comptime_int) struct { pos: Vec3, vel: Vec3, hit: bool } {
    var p = pos;
    var v = vel;
    var hit = false;
    const dt: f32 = 1.0 / @as(f32, @floatFromInt(steps));

    inline for (0..steps) |_| {
        const r = step(world, p, box, Vec3.scale(v, dt));
        p = r.pos;
        v = Vec3.scale(r.vel, 1.0 / dt);
        if (r.hit) hit = true;
    }

    return .{ .pos = p, .vel = v, .hit = hit };
}

pub fn step(world: anytype, pos: Vec3, box: BBox, vel: Vec3) struct { pos: Vec3, vel: Vec3, hit: bool } {
    var p = pos;
    var v = vel;
    var hit = false;

    for (0..3) |_| {
        const pl = box.at(p);
        const rg = pl.bounds(v);
        var c: f32 = 1;
        var n = Vec3.zero();
        var found = false;

        const bounds = .{
            @as(i32, @intFromFloat(@floor(rg.min.v[0]))),
            @as(i32, @intFromFloat(@floor(rg.max.v[0]))),
            @as(i32, @intFromFloat(@floor(rg.min.v[1]))),
            @as(i32, @intFromFloat(@floor(rg.max.v[1]))),
            @as(i32, @intFromFloat(@floor(rg.min.v[2]))),
            @as(i32, @intFromFloat(@floor(rg.max.v[2]))),
        };

        var x = bounds[0];
        while (x <= bounds[1]) : (x += 1) {
            var y = bounds[2];
            while (y <= bounds[3]) : (y += 1) {
                var z = bounds[4];
                while (z <= bounds[5]) : (z += 1) {
                    if (!world.get(x, y, z)) continue;

                    const b = Vec3.new(@floatFromInt(x), @floatFromInt(y), @floatFromInt(z));
                    const block_box = BBox{ .min = b, .max = Vec3.add(b, Vec3.new(1, 1, 1)) };

                    if (pl.sweep(v, block_box)) |col| {
                        if (col.t < c) {
                            c = col.t;
                            n = col.n;
                            found = true;
                        }
                    }
                }
            }
        }

        if (!found) {
            p = Vec3.add(p, v);
            break;
        }

        hit = true;
        p = Vec3.add(p, Vec3.scale(v, @max(0, c - 0.01)));
        const d = Vec3.dot(n, v);
        v = Vec3.sub(v, Vec3.scale(n, d));

        if (@sqrt(Vec3.dot(v, v)) < 0.0001) break;
    }

    return .{ .pos = p, .vel = v, .hit = hit };
}

pub fn checkStatic(world: anytype, aabb: BBox) bool {
    const bounds = .{
        @as(i32, @intFromFloat(@floor(aabb.min.v[0]))),
        @as(i32, @intFromFloat(@floor(aabb.max.v[0]))),
        @as(i32, @intFromFloat(@floor(aabb.min.v[1]))),
        @as(i32, @intFromFloat(@floor(aabb.max.v[1]))),
        @as(i32, @intFromFloat(@floor(aabb.min.v[2]))),
        @as(i32, @intFromFloat(@floor(aabb.max.v[2]))),
    };

    var x = bounds[0];
    while (x <= bounds[1]) : (x += 1) {
        var y = bounds[2];
        while (y <= bounds[3]) : (y += 1) {
            var z = bounds[4];
            while (z <= bounds[5]) : (z += 1) {
                if (world.get(x, y, z)) return true;
            }
        }
    }
    return false;
}
