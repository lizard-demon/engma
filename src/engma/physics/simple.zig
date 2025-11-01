// Physics body - velocity, movement, dynamics
const std = @import("std");
const math = @import("../lib/math.zig");

pub const Player = struct {
    pos: math.Vec3,
    vel: math.Vec3,
    yaw: f32,
    pitch: f32,
    ground: bool,
    prev_ground: bool,

    mx: f32,
    my: f32,
    size: math.Vec3,

    pub fn init(allocator: std.mem.Allocator) Player {
        _ = allocator;
        return .{
            .pos = math.Vec3.new(2, 3, 2),
            .vel = math.Vec3.zero(),
            .yaw = 0,
            .pitch = 0,
            .ground = false,
            .prev_ground = false,

            .mx = 0,
            .my = 0,
            .size = math.Vec3.new(0.8, 1.6, 0.8), // width, height, depth
        };
    }

    pub fn deinit(self: *Player, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn tick(self: *Player, dt: f32) void {
        _ = dt;
        // Basic physics update
        self.prev_ground = self.ground;
    }

    pub fn event(self: *Player, e: anytype) void {
        // Handle mouse events
        if (e.type == .MOUSE_MOVE) {
            const sensitivity = 0.008;
            self.yaw += e.mouse_dx * sensitivity;
            self.pitch = @max(-std.math.pi / 2.0, @min(std.math.pi / 2.0, self.pitch + e.mouse_dy * sensitivity));
        }
    }

    // Stub methods for compatibility
    pub fn handleMovement(self: *Player, keys: anytype, dt: f32) void {
        _ = self;
        _ = keys;
        _ = dt;
    }

    pub fn handleJump(self: *Player, keys: anytype, audio: anytype) void {
        _ = self;
        _ = keys;
        _ = audio;
    }

    pub fn handleCollision(self: *Player, world: anytype, audio: anytype, dt: f32) void {
        _ = self;
        _ = world;
        _ = audio;
        _ = dt;
    }

    pub fn box(self: *const Player) math.Box {
        const half = math.Vec3.scale(self.size, 0.5);
        return .{ .min = math.Vec3.sub(self.pos, half), .max = math.Vec3.add(self.pos, half) };
    }

    pub fn view(self: *const Player) math.Mat4 {
        const cy, const sy = .{ @cos(self.yaw), @sin(self.yaw) };
        const cp, const sp = .{ @cos(self.pitch), @sin(self.pitch) };

        const forward = math.Vec3.new(sy * cp, -sp, -cy * cp);
        const right = math.Vec3.new(cy, 0, sy);
        const up = math.Vec3.new(-sy * sp, -cp, cy * sp);

        const eye = self.pos;

        return .{ .m = .{
            right.v[0],                 up.v[0],                 -forward.v[0],               0,
            right.v[1],                 up.v[1],                 -forward.v[1],               0,
            right.v[2],                 up.v[2],                 -forward.v[2],               0,
            -math.Vec3.dot(right, eye), -math.Vec3.dot(up, eye), math.Vec3.dot(forward, eye), 1,
        } };
    }
};
