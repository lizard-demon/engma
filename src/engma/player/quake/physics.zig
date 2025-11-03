const std = @import("std");
const math = @import("../../lib/math.zig");
const collision = @import("collision.zig");
const config = @import("config.zig");

const Vec3 = math.Vec3;

pub fn updateMovement(player: anytype, dir: Vec3, dt: f32) void {
    const len = @sqrt(dir.v[0] * dir.v[0] + dir.v[2] * dir.v[2]);
    if (len < config.move.min_len) {
        if (player.ground) applyFriction(player, dt);
        return;
    }

    const wish = Vec3.new(dir.v[0] / len, 0, dir.v[2] / len);
    const base_speed: f32 = if (player.crouch) config.move.crouch_speed else config.move.speed;
    const max = if (player.ground) base_speed * len else @min(base_speed * len, config.move.air_cap);
    const add = @max(0, max - Vec3.dot(player.vel, wish));

    if (add > 0) {
        player.vel = Vec3.add(player.vel, Vec3.scale(wish, @min(config.move.accel * dt, add)));
    }

    if (player.ground) applyFriction(player, dt);
}

pub fn applyFriction(player: anytype, dt: f32) void {
    const s = @sqrt(player.vel.v[0] * player.vel.v[0] + player.vel.v[2] * player.vel.v[2]);
    if (s < config.friction.min_speed) {
        player.vel = Vec3.new(0, player.vel.v[1], 0);
        return;
    }
    const f = @max(0, s - @max(s, config.friction.min_speed) * config.friction.factor * dt) / s;
    player.vel = Vec3.new(player.vel.v[0] * f, player.vel.v[1], player.vel.v[2] * f);
}

pub fn updatePhysics(player: anytype, world: anytype, audio: anytype, dt: f32) void {
    player.vel = Vec3.new(player.vel.v[0], player.vel.v[1] - config.phys.gravity * dt, player.vel.v[2]);

    const h: f32 = if (player.crouch) config.size.crouch else config.size.stand;
    const box = collision.BBox{
        .min = Vec3.new(-config.size.width, -h / 2.0, -config.size.width),
        .max = Vec3.new(config.size.width, h / 2.0, config.size.width),
    };

    const r = collision.sweep(world, player.pos, box, Vec3.scale(player.vel, dt), config.phys.steps);
    player.pos = r.pos;
    player.vel = Vec3.scale(r.vel, 1.0 / dt);

    player.prev_ground = player.ground;
    player.ground = r.hit and @abs(r.vel.v[1]) < config.phys.ground_thresh;

    if (player.ground and !player.prev_ground and player.vel.v[1] < -2) {
        // Land sound: falling frequency with noise
        audio.playSound(0.08, 150.0, 80.0, 12.0, 0.2, 0.1);
    }

    if (player.pos.v[1] < 0 or player.pos.v[1] > 64) {
        player.pos = Vec3.new(2, 2, 2);
    }
}
