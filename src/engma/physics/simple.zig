// Physics body - velocity, movement, dynamics
const std = @import("std");
const math = @import("../lib/math.zig");

pub const Player = struct {
    pos: math.Vec,
    vel: math.Vec,
    yaw: f32,
    pitch: f32,
    ground: bool,
    prev_ground: bool,

    mx: f32,
    my: f32,
    size: math.Vec,

    pub fn init(allocator: std.mem.Allocator) Player {
        _ = allocator;
        return .{
            .pos = math.Vec.new(2, 3, 2),
            .vel = math.Vec.zero(),
            .yaw = 0,
            .pitch = 0,
            .ground = false,
            .prev_ground = false,

            .mx = 0,
            .my = 0,
            .size = math.Vec.new(0.8, 1.6, 0.8), // width, height, depth
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
        const half = math.Vec.scale(self.size, 0.5);
        return .{ .min = math.Vec.sub(self.pos, half), .max = math.Vec.add(self.pos, half) };
    }

    pub fn view(self: *const Player) math.Mat {
        const cy, const sy = .{ @cos(self.yaw), @sin(self.yaw) };
        const cp, const sp = .{ @cos(self.pitch), @sin(self.pitch) };

        const forward = math.Vec.new(sy * cp, -sp, -cy * cp);
        const right = math.Vec.new(cy, 0, sy);
        const up = math.Vec.new(-sy * sp, -cp, cy * sp);

        const eye = self.pos;

        return .{ .data = .{
            right.data[0],             up.data[0],             -forward.data[0],           0,
            right.data[1],             up.data[1],             -forward.data[1],           0,
            right.data[2],             up.data[2],             -forward.data[2],           0,
            -math.Vec.dot(right, eye), -math.Vec.dot(up, eye), math.Vec.dot(forward, eye), 1,
        } };
    }
};
