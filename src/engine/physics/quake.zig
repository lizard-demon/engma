// Quake movement physics - extracted from duel
const std = @import("std");
const math = @import("../lib/math.zig");
const sokol = @import("sokol");

const Vec = math.Vec;
const Mat = math.Mat;

pub const Player = struct {
    pos: Vec,
    vel: Vec,
    yaw: f32,
    pitch: f32,
    ground: bool,
    prev_ground: bool,
    crouch: bool,

    const cfg = struct {
        const size = struct {
            const stand = 1.8;
            const crouch = 0.9;
            const width = 0.49;
        };
        const move = struct {
            const speed = 4.0;
            const crouch_speed = speed / 2.0;
            const air_cap = 0.7;
            const accel = 70.0;
            const min_len = 0.001;
        };
        const phys = struct {
            const gravity = 12.0;
            const steps = 3;
            const ground_thresh = 0.01;
        };
        const friction = struct {
            const min_speed = 0.1;
            const factor = 5.0;
        };
        const jump_power = 4.0;
        const pitch_limit = std.math.pi / 2.0;
    };

    pub fn init(allocator: std.mem.Allocator) Player {
        _ = allocator;
        return .{
            .pos = Vec.new(2.0, 2.0, 2.0),
            .vel = Vec.zero(),
            .yaw = std.math.pi,
            .pitch = 0.0,
            .ground = false,
            .prev_ground = false,
            .crouch = false,
        };
    }

    pub fn deinit(self: *Player, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn tick(self: *Player, dt: f32) void {
        // TODO: Get world, keys, audio data generically
        _ = dt;
        // For now, just update basic physics
        self.prev_ground = self.ground;
        // TODO: Movement will be handled when we have generic data access

        // TODO: Quake movement will be implemented with generic data access

        // TODO: All physics interactions will be implemented with generic data access
    }

    pub const Update = struct {
        pub fn movement(self: *Player, dir: Vec, dt: f32) void {
            const len = @sqrt(dir.data[0] * dir.data[0] + dir.data[2] * dir.data[2]);
            if (len < cfg.move.min_len) return if (self.ground) Update.friction(self, dt);

            const wish = Vec.new(dir.data[0] / len, 0, dir.data[2] / len);
            const base_speed: f32 = if (self.crouch) cfg.move.crouch_speed else cfg.move.speed;
            const max = if (self.ground) base_speed * len else @min(base_speed * len, cfg.move.air_cap);
            const add = @max(0, max - Vec.dot(self.vel, wish));

            if (add > 0) {
                self.vel = Vec.add(self.vel, Vec.scale(wish, @min(cfg.move.accel * dt, add)));
            }

            if (self.ground) Update.friction(self, dt);
        }

        pub fn friction(self: *Player, dt: f32) void {
            const s = @sqrt(self.vel.data[0] * self.vel.data[0] + self.vel.data[2] * self.vel.data[2]);
            if (s < cfg.friction.min_speed) {
                self.vel.data[0] = 0;
                self.vel.data[2] = 0;
                return;
            }
            const f = @max(0, s - @max(s, cfg.friction.min_speed) * cfg.friction.factor * dt) / s;
            self.vel.data[0] *= f;
            self.vel.data[2] *= f;
        }

        pub fn physics(self: *Player, world: anytype, audio: anytype, dt: f32) void {
            self.vel.data[1] -= cfg.phys.gravity * dt;

            const h: f32 = if (self.crouch) cfg.size.crouch else cfg.size.stand;
            const box = BBox{
                .min = Vec.new(-cfg.size.width, -h / 2.0, -cfg.size.width),
                .max = Vec.new(cfg.size.width, h / 2.0, cfg.size.width),
            };

            const r = sweep(world, self.pos, box, Vec.scale(self.vel, dt), cfg.phys.steps);
            self.pos = r.pos;
            self.vel = Vec.scale(r.vel, 1 / dt);

            self.prev_ground = self.ground;
            self.ground = r.hit and @abs(r.vel.data[1]) < cfg.phys.ground_thresh;

            // Landing sound
            if (self.ground and !self.prev_ground and self.vel.data[1] < -2.0) {
                audio.land();
            }

            // Boundary check - reset if out of bounds
            if (self.pos.data[1] < 0.0 or self.pos.data[1] > 64.0) {
                self.pos = Vec.new(2.0, 2.0, 2.0);
            }
        }
    };

    pub fn view(self: *Player) Mat {
        const cy, const sy = .{ @cos(self.yaw), @sin(self.yaw) };
        const cp, const sp = .{ @cos(self.pitch), @sin(self.pitch) };
        const x, const y, const z = .{ self.pos.data[0], self.pos.data[1], self.pos.data[2] };

        return .{ .data = .{ cy, sy * sp, -sy * cp, 0, 0, cp, sp, 0, sy, -cy * sp, cy * cp, 0, -x * cy - z * sy, -x * sy * sp - y * cp + z * cy * sp, x * sy * cp - y * sp - z * cy * cp, 1 } };
    }

    pub fn event(self: *Player, e: anytype) void {
        // Handle mouse events
        if (e.type == .MOUSE_MOVE) {
            const sensitivity = 0.008;
            self.yaw += e.mouse_dx * sensitivity;
            self.pitch = @max(-cfg.pitch_limit, @min(cfg.pitch_limit, self.pitch + e.mouse_dy * sensitivity));
        }
    }
};

// Collision system
const BBox = struct {
    min: Vec,
    max: Vec,

    fn at(self: BBox, pos: Vec) BBox {
        return .{ .min = Vec.add(pos, self.min), .max = Vec.add(pos, self.max) };
    }

    fn bounds(self: BBox, vel: Vec) struct { min: Vec, max: Vec } {
        const sm = Vec.add(self.min, vel);
        const sx = Vec.add(self.max, vel);
        return .{ .min = Vec.new(@min(sm.data[0], self.min.data[0]), @min(sm.data[1], self.min.data[1]), @min(sm.data[2], self.min.data[2])), .max = Vec.new(@max(sx.data[0], self.max.data[0]), @max(sx.data[1], self.max.data[1]), @max(sx.data[2], self.max.data[2])) };
    }

    fn sweep(self: BBox, vel: Vec, other: BBox) ?struct { t: f32, n: Vec } {
        if (@sqrt(Vec.dot(vel, vel)) < 0.0001) return null;

        const inv = Vec.new(if (vel.data[0] != 0) 1 / vel.data[0] else std.math.inf(f32), if (vel.data[1] != 0) 1 / vel.data[1] else std.math.inf(f32), if (vel.data[2] != 0) 1 / vel.data[2] else std.math.inf(f32));

        const tx = axis(self.min.data[0], self.max.data[0], other.min.data[0], other.max.data[0], inv.data[0]);
        const ty = axis(self.min.data[1], self.max.data[1], other.min.data[1], other.max.data[1], inv.data[1]);
        const tz = axis(self.min.data[2], self.max.data[2], other.min.data[2], other.max.data[2], inv.data[2]);

        const enter = @max(@max(tx.enter, ty.enter), tz.enter);
        const exit = @min(@min(tx.exit, ty.exit), tz.exit);

        if (enter > exit or enter > 1 or exit < 0 or enter < 0) return null;

        const n = if (tx.enter > ty.enter and tx.enter > tz.enter)
            Vec.new(if (vel.data[0] > 0) -1 else 1, 0, 0)
        else if (ty.enter > tz.enter)
            Vec.new(0, if (vel.data[1] > 0) -1 else 1, 0)
        else
            Vec.new(0, 0, if (vel.data[2] > 0) -1 else 1);

        return .{ .t = enter, .n = n };
    }

    fn axis(min1: f32, max1: f32, min2: f32, max2: f32, inv: f32) struct { enter: f32, exit: f32 } {
        const t1 = (min2 - max1) * inv;
        const t2 = (max2 - min1) * inv;
        return .{ .enter = @min(t1, t2), .exit = @max(t1, t2) };
    }
};

fn sweep(world: anytype, pos: Vec, box: BBox, vel: Vec, comptime steps: comptime_int) struct { pos: Vec, vel: Vec, hit: bool } {
    var p = pos;
    var v = vel;
    var hit = false;
    const dt: f32 = 1.0 / @as(f32, @floatFromInt(steps));

    inline for (0..steps) |_| {
        const r = step(world, p, box, Vec.scale(v, dt));
        p = r.pos;
        v = Vec.scale(r.vel, 1 / dt);
        if (r.hit) hit = true;
    }

    return .{ .pos = p, .vel = v, .hit = hit };
}

fn step(world: anytype, pos: Vec, box: BBox, vel: Vec) struct { pos: Vec, vel: Vec, hit: bool } {
    var p = pos;
    var v = vel;
    var hit = false;

    for (0..3) |_| {
        const pl = box.at(p);
        const rg = pl.bounds(v);
        var c: f32 = 1;
        var n = Vec.zero();
        var found = false;

        const min_x = @as(i32, @intFromFloat(@floor(rg.min.data[0])));
        const max_x = @as(i32, @intFromFloat(@floor(rg.max.data[0])));
        const min_y = @as(i32, @intFromFloat(@floor(rg.min.data[1])));
        const max_y = @as(i32, @intFromFloat(@floor(rg.max.data[1])));
        const min_z = @as(i32, @intFromFloat(@floor(rg.min.data[2])));
        const max_z = @as(i32, @intFromFloat(@floor(rg.max.data[2])));

        var x = min_x;
        while (x <= max_x) : (x += 1) {
            var y = min_y;
            while (y <= max_y) : (y += 1) {
                var z = min_z;
                while (z <= max_z) : (z += 1) {
                    if (!world.get(x, y, z)) continue;

                    const b = Vec.new(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y)), @as(f32, @floatFromInt(z)));
                    const block_box = BBox{ .min = b, .max = Vec.add(b, Vec.new(1, 1, 1)) };

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
            p = Vec.add(p, v);
            break;
        }

        hit = true;
        p = Vec.add(p, Vec.scale(v, @max(0, c - 0.01)));
        const d = Vec.dot(n, v);
        v = Vec.sub(v, Vec.scale(n, d));

        if (@sqrt(Vec.dot(v, v)) < 0.0001) break;
    }

    return .{ .pos = p, .vel = v, .hit = hit };
}
fn checkStatic(world: anytype, aabb: BBox) bool {
    const min_x = @as(i32, @intFromFloat(@floor(aabb.min.data[0])));
    const max_x = @as(i32, @intFromFloat(@floor(aabb.max.data[0])));
    const min_y = @as(i32, @intFromFloat(@floor(aabb.min.data[1])));
    const max_y = @as(i32, @intFromFloat(@floor(aabb.max.data[1])));
    const min_z = @as(i32, @intFromFloat(@floor(aabb.min.data[2])));
    const max_z = @as(i32, @intFromFloat(@floor(aabb.max.data[2])));

    var x = min_x;
    while (x <= max_x) : (x += 1) {
        var y = min_y;
        while (y <= max_y) : (y += 1) {
            var z = min_z;
            while (z <= max_z) : (z += 1) {
                if (world.get(x, y, z)) return true;
            }
        }
    }
    return false;
}
