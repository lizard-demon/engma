const math = @import("../../lib/math.zig");
const config = @import("config.zig");
const Vec3 = math.Vec3;

pub fn applyMovement(player: anytype, fw: f32, st: f32, s: f32, c: f32, dt: f32) void {
    player.vel = Vec3.new((s * fw + c * st) * config.move_force, player.vel.v[1] + config.gravity * dt, (-c * fw + s * st) * config.move_force);
}

pub fn jump(player: anytype) void {
    player.vel = Vec3.new(player.vel.v[0], config.jump_force, player.vel.v[2]);
}
