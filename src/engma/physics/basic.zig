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
    size: Vec3,

    pub fn init(_: std.mem.Allocator) Player {
        return .{
            .pos = Vec3.new(2, 3, 2),
            .vel = Vec3.zero(),
            .yaw = 0,
            .pitch = 0,
            .ground = false,
            .prev_ground = false,
            .size = Vec3.new(0.8, 1.6, 0.8), // width, height, depth
        };
    }

    pub fn deinit(_: *Player, _: std.mem.Allocator) void {}

    pub fn tick(self: *Player, _: f32) void {
        self.prev_ground = self.ground;
    }

    pub fn handleMovement(self: *Player, keys: anytype, world: anytype, _: anytype, dt: f32) void {
        // Movement input
        const s, const c = .{ @sin(self.yaw), @cos(self.yaw) };
        const fw: f32 = if (keys.forward()) 1 else if (keys.back()) -1 else 0;
        const st: f32 = if (keys.right()) 1 else if (keys.left()) -1 else 0;

        // Apply forces
        const move_force = 6.0;
        const gravity = -15.0;
        const jump_force = 8.0;

        self.vel = Vec3.new((s * fw + c * st) * move_force, self.vel.v[1] + gravity * dt, (-c * fw + s * st) * move_force);

        if (keys.jump() and self.ground) {
            self.vel = Vec3.new(self.vel.v[0], jump_force, self.vel.v[2]);
        }

        // Collision detection per axis
        const old_pos = self.pos;
        self.prev_ground = self.ground;
        self.ground = false;

        // Check X, Z, Y axes in that order
        inline for (.{ 0, 2, 1 }) |axis| {
            self.pos = Vec3.new(if (axis == 0) self.pos.v[0] + self.vel.v[0] * dt else self.pos.v[0], if (axis == 1) self.pos.v[1] + self.vel.v[1] * dt else self.pos.v[1], if (axis == 2) self.pos.v[2] + self.vel.v[2] * dt else self.pos.v[2]);

            if (self.checkCollision(world)) {
                // Revert position
                self.pos = Vec3.new(if (axis == 0) old_pos.v[0] else self.pos.v[0], if (axis == 1) old_pos.v[1] else self.pos.v[1], if (axis == 2) old_pos.v[2] else self.pos.v[2]);

                if (axis == 1) { // Y axis
                    if (self.vel.v[1] <= 0) self.ground = true;
                    self.vel = Vec3.new(self.vel.v[0], 0, self.vel.v[2]);
                } else {
                    // Stop horizontal movement on collision
                    self.vel = Vec3.new(if (axis == 0) 0 else self.vel.v[0], self.vel.v[1], if (axis == 2) 0 else self.vel.v[2]);
                }
            }
        }

        // Floor clamp
        if (self.pos.v[1] < self.size.v[1] * 0.5) {
            self.pos = Vec3.new(self.pos.v[0], self.size.v[1] * 0.5, self.pos.v[2]);
            self.vel = Vec3.new(self.vel.v[0], 0, self.vel.v[2]);
            self.ground = true;
        }
    }

    pub fn view(self: *Player) Mat4 {
        const cy, const sy = .{ @cos(self.yaw), @sin(self.yaw) };
        const cp, const sp = .{ @cos(self.pitch), @sin(self.pitch) };

        // Camera offset (eye position relative to body center)
        const eye_offset = Vec3.new(0, self.size.v[1] * 0.4, 0);
        const eye_pos = Vec3.add(self.pos, eye_offset);

        return .{ .m = .{
            cy,                                     sy * sp,                                                              -sy * cp,                                                            0,
            0,                                      cp,                                                                   sp,                                                                  0,
            sy,                                     -cy * sp,                                                             cy * cp,                                                             0,
            -eye_pos.v[0] * cy - eye_pos.v[2] * sy, -eye_pos.v[0] * sy * sp - eye_pos.v[1] * cp + eye_pos.v[2] * cy * sp, eye_pos.v[0] * sy * cp - eye_pos.v[1] * sp - eye_pos.v[2] * cy * cp, 1,
        } };
    }

    pub fn event(self: *Player, e: anytype) void {
        if (e.type == .MOUSE_MOVE) {
            const sensitivity = 0.002;
            self.yaw += e.mouse_dx * sensitivity;
            self.pitch = std.math.clamp(self.pitch + e.mouse_dy * sensitivity, -1.5, 1.5);
        }
    }

    fn box(self: *const Player) BBox {
        const half = Vec3.scale(self.size, 0.5);
        return .{
            .min = Vec3.sub(self.pos, half),
            .max = Vec3.add(self.pos, half),
        };
    }

    fn checkCollision(self: *const Player, world: anytype) bool {
        const bbox = self.box();
        const min_x = @as(i32, @intFromFloat(@floor(bbox.min.v[0])));
        const max_x = @as(i32, @intFromFloat(@floor(bbox.max.v[0])));
        const min_y = @as(i32, @intFromFloat(@floor(bbox.min.v[1])));
        const max_y = @as(i32, @intFromFloat(@floor(bbox.max.v[1])));
        const min_z = @as(i32, @intFromFloat(@floor(bbox.min.v[2])));
        const max_z = @as(i32, @intFromFloat(@floor(bbox.max.v[2])));

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
};

const BBox = struct {
    min: Vec3,
    max: Vec3,
};
