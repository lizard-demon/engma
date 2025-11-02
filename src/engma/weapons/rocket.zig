const std = @import("std");
const math = @import("../lib/math.zig");

const Vec3 = math.Vec3;

// Global audio state for explosions (similar to quake physics audio)
var explosion_audio_time: f32 = 0;
var explosion_audio_phase: f32 = 0;

const Projectile = struct {
    pos: Vec3,
    vel: Vec3,
    lifetime: f32,
    active: bool,
};

const Explosion = struct {
    pos: Vec3,
    time: f32,
    max_time: f32,
    active: bool,
};

pub const Weapons = struct {
    projectiles: [32]Projectile,
    explosions: [16]Explosion,
    projectile_count: usize,
    explosion_count: usize,
    fire_cooldown: f32,

    const cfg = struct {
        const rocket_speed = 20.0;
        const rocket_lifetime = 10.0;
        const fire_rate = 0.8; // seconds between shots
        const explosion_radius = 4.0;
        const rocket_jump_force = 8.0;
        const max_projectiles = 32;
        const explosion_duration = 0.5;
    };

    pub fn init(_: std.mem.Allocator) Weapons {
        return .{
            .projectiles = [_]Projectile{.{
                .pos = Vec3.zero(),
                .vel = Vec3.zero(),
                .lifetime = 0.0,
                .active = false,
            }} ** 32,
            .explosions = [_]Explosion{.{
                .pos = Vec3.zero(),
                .time = 0.0,
                .max_time = 0.0,
                .active = false,
            }} ** 16,
            .projectile_count = 0,
            .explosion_count = 0,
            .fire_cooldown = 0.0,
        };
    }

    pub fn deinit(_: *Weapons, _: std.mem.Allocator) void {}

    pub fn tick(self: *Weapons, body: anytype, world: anytype, keys: anytype, audio: anytype, dt: f32) void {
        // Update fire cooldown
        self.fire_cooldown = @max(0.0, self.fire_cooldown - dt);

        // Handle firing
        if (keys.attack() and self.fire_cooldown <= 0.0 and self.projectile_count < cfg.max_projectiles) {
            self.fireRocket(body);
            self.fire_cooldown = cfg.fire_rate;
        }

        // Update projectiles
        for (&self.projectiles) |*rocket| {
            if (!rocket.active) continue;

            // Move rocket
            rocket.pos = Vec3.add(rocket.pos, Vec3.scale(rocket.vel, dt));
            rocket.lifetime -= dt;

            // Check for collision or timeout
            const hit_world = world.get(@as(i32, @intFromFloat(@floor(rocket.pos.v[0]))), @as(i32, @intFromFloat(@floor(rocket.pos.v[1]))), @as(i32, @intFromFloat(@floor(rocket.pos.v[2]))));

            if (hit_world or rocket.lifetime <= 0.0) {
                // Explode!
                self.explode(rocket.pos, body, world, audio);
                rocket.active = false;
                self.projectile_count -= 1;
            }
        }

        // Update explosions
        for (&self.explosions) |*explosion| {
            if (!explosion.active) continue;

            explosion.time += dt;
            if (explosion.time >= explosion.max_time) {
                explosion.active = false;
                self.explosion_count -= 1;
            }
        }
    }

    fn fireRocket(self: *Weapons, body: anytype) void {
        // Find empty slot
        for (&self.projectiles) |*slot| {
            if (slot.active) continue;

            // Get forward direction from body's yaw and pitch
            const yaw = body.yaw;
            const pitch = body.pitch;

            const cy = @cos(yaw);
            const sy = @sin(yaw);
            const cp = @cos(pitch);
            const sp = @sin(pitch);

            // Forward vector
            const forward = Vec3.new(sy * cp, -sp, -cy * cp);

            // Spawn rocket slightly in front of player
            const spawn_offset = Vec3.scale(forward, 1.5);
            const rocket_pos = Vec3.add(body.pos, spawn_offset);

            // Rocket velocity
            const rocket_vel = Vec3.scale(forward, cfg.rocket_speed);

            slot.* = .{
                .pos = rocket_pos,
                .vel = rocket_vel,
                .lifetime = cfg.rocket_lifetime,
                .active = true,
            };

            self.projectile_count += 1;
            break;
        }
    }

    fn explode(self: *Weapons, explosion_pos: Vec3, body: anytype, world: anytype, audio: anytype) void {
        _ = world; // TODO: Add world destruction
        _ = audio; // TODO: Add explosion sound

        // Create explosion visual effect
        for (&self.explosions) |*slot| {
            if (slot.active) continue;

            slot.* = .{
                .pos = explosion_pos,
                .time = 0.0,
                .max_time = cfg.explosion_duration,
                .active = true,
            };

            self.explosion_count += 1;
            break;
        }

        // Trigger explosion sound
        explosion_audio_time = 0.3; // 0.3 second explosion sound
        explosion_audio_phase = 0.0;

        // Calculate distance to player
        const to_player = Vec3.sub(body.pos, explosion_pos);
        const player_dist = Vec3.length(to_player);

        // Apply rocket jump force if player is within explosion radius
        if (player_dist <= cfg.explosion_radius) {
            if (player_dist > 0.001) {
                // Normalize direction
                const direction = Vec3.normalize(to_player);

                // Calculate falloff (closer = more force)
                const falloff = 1.0 - (player_dist / cfg.explosion_radius);
                const force_magnitude = cfg.rocket_jump_force * falloff;

                // Apply force to player velocity
                const force = Vec3.scale(direction, force_magnitude);
                body.vel = Vec3.add(body.vel, force);
            }
        }
    }

    // Visual data for rendering
    pub fn addVisuals(self: *const Weapons, vertices: []math.Vertex, indices: []u16, vi: *usize, ii: *usize) void {
        // Draw projectiles as small cubes
        for (self.projectiles) |rocket| {
            if (!rocket.active) continue;

            self.addCube(rocket.pos, 0.2, [4]f32{ 1.0, 0.5, 0.0, 1.0 }, vertices, indices, vi, ii); // Orange rockets
        }

        // Draw explosions as expanding spheres
        for (self.explosions) |explosion| {
            if (!explosion.active) continue;

            const progress = explosion.time / explosion.max_time;
            const size = progress * 2.0; // Expand over time
            const alpha = 1.0 - progress; // Fade out over time

            self.addCube(explosion.pos, size, [4]f32{ 1.0, 0.8, 0.0, alpha }, vertices, indices, vi, ii); // Yellow explosions
        }
    }

    fn addCube(self: *const Weapons, pos: Vec3, size: f32, color: [4]f32, vertices: []math.Vertex, indices: []u16, vi: *usize, ii: *usize) void {
        _ = self;

        if (vi.* + 8 > vertices.len or ii.* + 36 > indices.len) return;

        const half = size * 0.5;
        const base = @as(u16, @intCast(vi.*));

        // Cube vertices
        const cube_verts = [8][3]f32{
            .{ pos.v[0] - half, pos.v[1] - half, pos.v[2] - half },
            .{ pos.v[0] + half, pos.v[1] - half, pos.v[2] - half },
            .{ pos.v[0] + half, pos.v[1] + half, pos.v[2] - half },
            .{ pos.v[0] - half, pos.v[1] + half, pos.v[2] - half },
            .{ pos.v[0] - half, pos.v[1] - half, pos.v[2] + half },
            .{ pos.v[0] + half, pos.v[1] - half, pos.v[2] + half },
            .{ pos.v[0] + half, pos.v[1] + half, pos.v[2] + half },
            .{ pos.v[0] - half, pos.v[1] + half, pos.v[2] + half },
        };

        // Add vertices
        for (cube_verts) |vert| {
            vertices[vi.*] = .{ .pos = vert, .col = color };
            vi.* += 1;
        }

        // Cube indices (12 triangles)
        const cube_indices = [36]u16{
            // Front face
            0, 1, 2, 0, 2, 3,
            // Back face
            4, 6, 5, 4, 7, 6,
            // Left face
            0, 3, 7, 0, 7, 4,
            // Right face
            1, 5, 6, 1, 6, 2,
            // Top face
            3, 2, 6, 3, 6, 7,
            // Bottom face
            0, 4, 5, 0, 5, 1,
        };

        // Add indices
        for (cube_indices) |idx| {
            indices[ii.*] = base + idx;
            ii.* += 1;
        }
    }
};

// Audio generation for explosions (global function like quake physics)
pub fn generateExplosionAudio() f32 {
    var sample: f32 = 0.0;
    const dt = 1.0 / 44100.0;

    if (explosion_audio_time > 0.0) {
        const progress = 1.0 - (explosion_audio_time / 0.3);

        // Low frequency rumble
        const rumble_freq = 60.0 - 30.0 * progress;
        const rumble = @sin(explosion_audio_phase * 2.0 * std.math.pi * rumble_freq / 44100.0);

        // High frequency crack
        const crack_freq = 800.0 + 400.0 * progress;
        const crack = @sin(explosion_audio_phase * 2.0 * std.math.pi * crack_freq / 44100.0);

        // Noise component
        const noise = (@sin(explosion_audio_phase * 17.3) + @sin(explosion_audio_phase * 23.7)) * 0.3;

        // Envelope (sharp attack, exponential decay)
        const envelope = @exp(-progress * 8.0);

        // Mix components
        sample = (rumble * 0.6 + crack * 0.3 + noise * 0.1) * envelope * 0.4;

        explosion_audio_phase += 1.0;
        explosion_audio_time = @max(0.0, explosion_audio_time - dt);
    }

    return @max(-1.0, @min(1.0, sample));
}
