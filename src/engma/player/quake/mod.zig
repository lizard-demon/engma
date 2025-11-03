const std = @import("std");
const math = @import("../../lib/math.zig");
const physics = @import("physics.zig");
const collision = @import("collision.zig");
const config = @import("config.zig");

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

    pub fn init(self: *Player, _: anytype) void {
        self.* = .{
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

    pub fn event(self: *Player, engine: anytype) void {
        const e = engine.event;
        if (e.type == .MOUSE_MOVE and engine.systems.keys.locked) {
            const sensitivity = 0.008;
            self.yaw += e.mouse_dx * sensitivity;
            self.pitch = std.math.clamp(self.pitch + e.mouse_dy * sensitivity, -config.pitch_limit, config.pitch_limit);
        }
    }

    pub fn handleMovement(self: *Player, state: anytype) void {
        // Movement input
        var dir = Vec3.zero();
        const fw: f32 = if (state.systems.keys.forward()) 1 else if (state.systems.keys.back()) -1 else 0;
        const st: f32 = if (state.systems.keys.right()) 1 else if (state.systems.keys.left()) -1 else 0;

        if (st != 0) dir = Vec3.add(dir, Vec3.scale(Vec3.new(@cos(self.yaw), 0, @sin(self.yaw)), st));
        if (fw != 0) dir = Vec3.add(dir, Vec3.scale(Vec3.new(@sin(self.yaw), 0, -@cos(self.yaw)), fw));

        physics.updateMovement(self, dir, state.dt);

        // Crouch handling
        const want_crouch = state.systems.keys.crouch();
        if (self.crouch and !want_crouch) {
            const height_diff = (config.size.stand - config.size.crouch) / 2.0;
            const test_pos = Vec3.new(self.pos.v[0], self.pos.v[1] + height_diff, self.pos.v[2]);
            const standing_box = collision.BBox{
                .min = Vec3.new(-config.size.width, -config.size.stand / 2.0, -config.size.width),
                .max = Vec3.new(config.size.width, config.size.stand / 2.0, config.size.width),
            };

            if (!collision.checkStatic(&state.systems.world, standing_box.at(test_pos))) {
                self.pos = Vec3.new(self.pos.v[0], self.pos.v[1] + height_diff, self.pos.v[2]);
                self.crouch = false;
            }
        } else {
            self.crouch = want_crouch;
        }

        // Jump
        if (state.systems.keys.jump() and self.ground) {
            self.vel = Vec3.new(self.vel.v[0], config.jump_power, self.vel.v[2]);
            self.ground = false;
            // Jump sound: rising frequency, quick decay
            state.systems.audio.playSound(0.15, 220.0, 440.0, 8.0, 0.3, 0.0);
        }

        physics.updatePhysics(self, &state.systems.world, &state.systems.audio, state.dt);
    }

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
