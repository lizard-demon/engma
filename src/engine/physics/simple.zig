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

    pub fn init() Player {
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

    pub fn box(self: *const Player) math.Box {
        const half = math.Vec.scale(self.size, 0.5);
        return .{ .min = math.Vec.sub(self.pos, half), .max = math.Vec.add(self.pos, half) };
    }

    pub fn tick(self: *Player, world: anytype, keys: anytype, audio: anytype, dt: f32) void {
        // Mouse look
        self.yaw += self.mx * 0.002;
        self.pitch = std.math.clamp(self.pitch + self.my * 0.002, -1.5, 1.5);
        self.mx = 0;
        self.my = 0;

        // Movement input
        const s, const c = .{ @sin(self.yaw), @cos(self.yaw) };
        const fw: f32 = if (keys.forward()) 1 else if (keys.back()) -1 else 0;
        const st: f32 = if (keys.right()) 1 else if (keys.left()) -1 else 0;

        // Apply forces
        const move_force = 6.0;
        const gravity = -15.0;
        const jump_force = 8.0;

        self.vel = math.Vec.new((s * fw + c * st) * move_force, self.vel.data[1] + gravity * dt, (-c * fw + s * st) * move_force);

        if (keys.jump() and self.ground) {
            self.vel.data[1] = jump_force;
            audio.jump();
        }

        // Collision detection per axis - integrated collision system
        const old_pos = self.pos;
        self.prev_ground = self.ground;
        self.ground = false;

        inline for (.{ 0, 2, 1 }) |axis| {
            self.pos.data[axis] += self.vel.data[axis] * dt;

            if (self.checkCollision(world)) {
                self.pos.data[axis] = old_pos.data[axis];

                if (axis == 1) { // Y axis
                    if (self.vel.data[1] <= 0) {
                        self.ground = true;
                        if (!self.prev_ground and self.vel.data[1] < -5.0) {
                            audio.land();
                        }
                    }
                    self.vel.data[1] = 0;
                } else {
                    // Stop horizontal movement on collision
                    self.vel.data[axis] = 0;
                }
            }
        }

        // Floor clamp
        if (self.pos.data[1] < self.size.data[1] * 0.5) {
            self.pos.data[1] = self.size.data[1] * 0.5;
            if (!self.prev_ground and self.vel.data[1] < -5.0) {
                audio.land();
            }
            self.vel.data[1] = 0;
            self.ground = true;
        }
    }

    pub fn view(self: *const Player) math.Mat {
        const cy, const sy = .{ @cos(self.yaw), @sin(self.yaw) };
        const cp, const sp = .{ @cos(self.pitch), @sin(self.pitch) };

        // Camera offset (eye position relative to body center)
        const eye_offset = math.Vec.new(0, self.size.data[1] * 0.4, 0);
        const eye_pos = math.Vec.add(self.pos, eye_offset);

        return .{ .data = .{ cy, sy * sp, -sy * cp, 0, 0, cp, sp, 0, sy, -cy * sp, cy * cp, 0, -eye_pos.data[0] * cy - eye_pos.data[2] * sy, -eye_pos.data[0] * sy * sp - eye_pos.data[1] * cp + eye_pos.data[2] * cy * sp, eye_pos.data[0] * sy * cp - eye_pos.data[1] * sp - eye_pos.data[2] * cy * cp, 1 } };
    }

    pub fn mouse(self: *Player, dx: f32, dy: f32) void {
        self.mx += dx;
        self.my += dy;
    }

    fn checkCollision(self: *const Player, world: anytype) bool {
        const bbox = self.box();
        const min_x = @as(i32, @intFromFloat(@floor(bbox.min.data[0])));
        const max_x = @as(i32, @intFromFloat(@floor(bbox.max.data[0])));
        const min_y = @as(i32, @intFromFloat(@floor(bbox.min.data[1])));
        const max_y = @as(i32, @intFromFloat(@floor(bbox.max.data[1])));
        const min_z = @as(i32, @intFromFloat(@floor(bbox.min.data[2])));
        const max_z = @as(i32, @intFromFloat(@floor(bbox.max.data[2])));

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
