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
    size: Vec3,

    pub fn init(self: *Player, _: anytype) void {
        self.* = .{
            .pos = Vec3.new(2, 3, 2),
            .vel = Vec3.zero(),
            .yaw = 0,
            .pitch = 0,
            .ground = false,
            .prev_ground = false,
            .size = Vec3.new(config.size.width, config.size.height, config.size.depth),
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
            self.yaw += e.mouse_dx * config.sensitivity;
            self.pitch = std.math.clamp(self.pitch + e.mouse_dy * config.sensitivity, -config.pitch_limit, config.pitch_limit);
        }
    }

    pub fn handleMovement(self: *Player, state: anytype) void {
        const s, const c = .{ @sin(self.yaw), @cos(self.yaw) };
        const fw: f32 = if (state.systems.keys.forward()) 1 else if (state.systems.keys.back()) -1 else 0;
        const st: f32 = if (state.systems.keys.right()) 1 else if (state.systems.keys.left()) -1 else 0;

        physics.applyMovement(self, fw, st, s, c, state.dt);

        if (state.systems.keys.jump() and self.ground) {
            physics.jump(self);
        }

        collision.resolveCollisions(self, &state.systems.world, state.dt);
    }

    pub fn view(self: Player) Mat4 {
        const cy, const sy = .{ @cos(self.yaw), @sin(self.yaw) };
        const cp, const sp = .{ @cos(self.pitch), @sin(self.pitch) };
        const eye_offset = Vec3.new(0, self.size.v[1] * config.eye_height, 0);
        const eye_pos = Vec3.add(self.pos, eye_offset);

        return .{ .m = .{
            cy,                                     sy * sp,                                                              -sy * cp,                                                            0,
            0,                                      cp,                                                                   sp,                                                                  0,
            sy,                                     -cy * sp,                                                             cy * cp,                                                             0,
            -eye_pos.v[0] * cy - eye_pos.v[2] * sy, -eye_pos.v[0] * sy * sp - eye_pos.v[1] * cp + eye_pos.v[2] * cy * sp, eye_pos.v[0] * sy * cp - eye_pos.v[1] * sp - eye_pos.v[2] * cy * cp, 1,
        } };
    }
};
