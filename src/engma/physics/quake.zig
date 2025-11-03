const std = @import("std");
const math = @import("../lib/math.zig");

const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

pub const Player = struct {
    pos: Vec3,
    vel: Vec3,
    yaw: f32,
    pitch: f32,
    ground: bool,
    prev_ground: bool,
    crouch: bool,

    const cfg = struct {
        const size = .{ .stand = 1.8, .crouch = 0.9, .width = 0.49 };
        const move = .{ .speed = 4.0, .crouch_speed = 2.0, .air_cap = 0.7, .accel = 70.0, .min_len = 0.001 };
        const phys = .{ .gravity = 12.0, .steps = 3, .ground_thresh = 0.01 };
        const friction = .{ .min_speed = 0.1, .factor = 5.0 };
        const jump_power = 4.0;
        const pitch_limit = std.math.pi / 2.0;
    };

    pub fn init(_: std.mem.Allocator) Player {
        return .{
            .pos = Vec3.new(2, 2, 2),
            .vel = Vec3.zero(),
            .yaw = std.math.pi,
            .pitch = 0,
            .ground = false,
            .prev_ground = false,
            .crouch = false,
        };
    }

    pub fn deinit(_: *Player, _: anytype) void {}

    pub fn tick(self: *Player, state: anytype) void {
        self.prev_ground = self.ground;
        self.handleMovement(state);
    }

    pub fn draw(_: *Player, _: anytype) void {}

    pub fn event(self: *Player, _: anytype, e: anytype) void {
        if (e.type == .MOUSE_MOVE) {
            const sensitivity = 0.008;
            self.yaw += e.mouse_dx * sensitivity;
            self.pitch = std.math.clamp(self.pitch + e.mouse_dy * sensitivity, -cfg.pitch_limit, cfg.pitch_limit);
        }
    }

    pub fn handleMovement(self: *Player, state: anytype) void {
        // Movement input
        var dir = Vec3.zero();
        const fw: f32 = if (state.systems.keys.forward()) 1 else if (state.systems.keys.back()) -1 else 0;
        const st: f32 = if (state.systems.keys.right()) 1 else if (state.systems.keys.left()) -1 else 0;

        if (st != 0) dir = Vec3.add(dir, Vec3.scale(Vec3.new(@cos(self.yaw), 0, @sin(self.yaw)), st));
        if (fw != 0) dir = Vec3.add(dir, Vec3.scale(Vec3.new(@sin(self.yaw), 0, -@cos(self.yaw)), fw));

        Update.movement(self, dir, state.dt);

        // Crouch handling
        const want_crouch = state.systems.keys.crouch();
        if (self.crouch and !want_crouch) {
            const height_diff = (cfg.size.stand - cfg.size.crouch) / 2.0;
            const test_pos = Vec3.new(self.pos.v[0], self.pos.v[1] + height_diff, self.pos.v[2]);
            const standing_box = BBox{
                .min = Vec3.new(-cfg.size.width, -cfg.size.stand / 2.0, -cfg.size.width),
                .max = Vec3.new(cfg.size.width, cfg.size.stand / 2.0, cfg.size.width),
            };

            if (!checkStatic(&state.systems.world, standing_box.at(test_pos))) {
                self.pos = Vec3.new(self.pos.v[0], self.pos.v[1] + height_diff, self.pos.v[2]);
                self.crouch = false;
            }
        } else {
            self.crouch = want_crouch;
        }

        // Jump
        if (state.systems.keys.jump() and self.ground) {
            self.vel = Vec3.new(self.vel.v[0], cfg.jump_power, self.vel.v[2]);
            self.ground = false;
            state.systems.audio.jump();
        }

        Update.physics(self, &state.systems.world, &state.systems.audio, state.dt);
    }

    const Update = struct {
        fn movement(self: *Player, dir: Vec3, dt: f32) void {
            const len = @sqrt(dir.v[0] * dir.v[0] + dir.v[2] * dir.v[2]);
            if (len < cfg.move.min_len) {
                if (self.ground) friction(self, dt);
                return;
            }

            const wish = Vec3.new(dir.v[0] / len, 0, dir.v[2] / len);
            const base_speed: f32 = if (self.crouch) cfg.move.crouch_speed else cfg.move.speed;
            const max = if (self.ground) base_speed * len else @min(base_speed * len, cfg.move.air_cap);
            const add = @max(0, max - Vec3.dot(self.vel, wish));

            if (add > 0) {
                self.vel = Vec3.add(self.vel, Vec3.scale(wish, @min(cfg.move.accel * dt, add)));
            }

            if (self.ground) friction(self, dt);
        }

        fn friction(self: *Player, dt: f32) void {
            const s = @sqrt(self.vel.v[0] * self.vel.v[0] + self.vel.v[2] * self.vel.v[2]);
            if (s < cfg.friction.min_speed) {
                self.vel = Vec3.new(0, self.vel.v[1], 0);
                return;
            }
            const f = @max(0, s - @max(s, cfg.friction.min_speed) * cfg.friction.factor * dt) / s;
            self.vel = Vec3.new(self.vel.v[0] * f, self.vel.v[1], self.vel.v[2] * f);
        }

        fn physics(self: *Player, world: anytype, audio: anytype, dt: f32) void {
            self.vel = Vec3.new(self.vel.v[0], self.vel.v[1] - cfg.phys.gravity * dt, self.vel.v[2]);

            const h: f32 = if (self.crouch) cfg.size.crouch else cfg.size.stand;
            const box = BBox{
                .min = Vec3.new(-cfg.size.width, -h / 2.0, -cfg.size.width),
                .max = Vec3.new(cfg.size.width, h / 2.0, cfg.size.width),
            };

            const r = sweep(world, self.pos, box, Vec3.scale(self.vel, dt), cfg.phys.steps);
            self.pos = r.pos;
            self.vel = Vec3.scale(r.vel, 1.0 / dt);

            self.prev_ground = self.ground;
            self.ground = r.hit and @abs(r.vel.v[1]) < cfg.phys.ground_thresh;

            if (self.ground and !self.prev_ground and self.vel.v[1] < -2) {
                audio.land();
            }

            if (self.pos.v[1] < 0 or self.pos.v[1] > 64) {
                self.pos = Vec3.new(2, 2, 2);
            }
        }
    };

    pub fn view(self: Player) Mat4 {
        const cy, const sy = .{ @cos(self.yaw), @sin(self.yaw) };
        const cp, const sp = .{ @cos(self.pitch), @sin(self.pitch) };
        const x, const y, const z = .{ self.pos.v[0], self.pos.v[1], self.pos.v[2] };

        return .{ .m = .{
            cy,               sy * sp,                             -sy * cp,                           0,
            0,                cp,                                  sp,                                 0,
            sy,               -cy * sp,                            cy * cp,                            0,
            -x * cy - z * sy, -x * sy * sp - y * cp + z * cy * sp, x * sy * cp - y * sp - z * cy * cp, 1,
        } };
    }
};

const BBox = struct {
    min: Vec3,
    max: Vec3,

    fn at(self: BBox, pos: Vec3) BBox {
        return .{ .min = Vec3.add(pos, self.min), .max = Vec3.add(pos, self.max) };
    }

    fn bounds(self: BBox, vel: Vec3) struct { min: Vec3, max: Vec3 } {
        const sm = Vec3.add(self.min, vel);
        const sx = Vec3.add(self.max, vel);
        return .{
            .min = Vec3.new(@min(sm.v[0], self.min.v[0]), @min(sm.v[1], self.min.v[1]), @min(sm.v[2], self.min.v[2])),
            .max = Vec3.new(@max(sx.v[0], self.max.v[0]), @max(sx.v[1], self.max.v[1]), @max(sx.v[2], self.max.v[2])),
        };
    }

    fn sweep(self: BBox, vel: Vec3, other: BBox) ?struct { t: f32, n: Vec3 } {
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

fn sweep(world: anytype, pos: Vec3, box: BBox, vel: Vec3, comptime steps: comptime_int) struct { pos: Vec3, vel: Vec3, hit: bool } {
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

fn step(world: anytype, pos: Vec3, box: BBox, vel: Vec3) struct { pos: Vec3, vel: Vec3, hit: bool } {
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
fn checkStatic(world: anytype, aabb: BBox) bool {
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
