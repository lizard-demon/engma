const std = @import("std");
const math = @import("../lib/math.zig");

const Vec3 = math.Vec3;

const Projectile = struct {
    pos: Vec3,
    vel: Vec3,
    lifetime: f32,
    active: bool,
};

pub const Weapons = struct {
    projectiles: [32]Projectile,
    projectile_count: usize,
    fire_cooldown: f32,

    const cfg = struct {
        const rocket_speed = 20.0;
        const rocket_lifetime = 10.0;
        const fire_rate = 0.8; // seconds between shots
        const explosion_radius = 4.0;
        const rocket_jump_force = 8.0;
        const max_projectiles = 32;
    };

    pub fn init(_: std.mem.Allocator) Weapons {
        return .{
            .projectiles = [_]Projectile{.{
                .pos = Vec3.zero(),
                .vel = Vec3.zero(),
                .lifetime = 0.0,
                .active = false,
            }} ** 32,
            .projectile_count = 0,
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
        _ = self;
        _ = world; // TODO: Add world destruction
        _ = audio; // TODO: Add explosion sound

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
};
