const math = @import("../../lib/math.zig");
const Vec3 = math.Vec3;

pub const BBox = struct { min: Vec3, max: Vec3 };

pub fn resolveCollisions(player: anytype, world: anytype, dt: f32) void {
    const old_pos = player.pos;
    player.prev_ground = player.ground;
    player.ground = false;

    inline for (.{ 0, 2, 1 }) |axis| {
        player.pos = Vec3.new(if (axis == 0) player.pos.v[0] + player.vel.v[0] * dt else player.pos.v[0], if (axis == 1) player.pos.v[1] + player.vel.v[1] * dt else player.pos.v[1], if (axis == 2) player.pos.v[2] + player.vel.v[2] * dt else player.pos.v[2]);

        if (checkCollision(player, world)) {
            player.pos = Vec3.new(if (axis == 0) old_pos.v[0] else player.pos.v[0], if (axis == 1) old_pos.v[1] else player.pos.v[1], if (axis == 2) old_pos.v[2] else player.pos.v[2]);
            if (axis == 1) {
                if (player.vel.v[1] <= 0) player.ground = true;
                player.vel = Vec3.new(player.vel.v[0], 0, player.vel.v[2]);
            } else {
                player.vel = Vec3.new(if (axis == 0) 0 else player.vel.v[0], player.vel.v[1], if (axis == 2) 0 else player.vel.v[2]);
            }
        }
    }

    if (player.pos.v[1] < player.size.v[1] * 0.5) {
        player.pos = Vec3.new(player.pos.v[0], player.size.v[1] * 0.5, player.pos.v[2]);
        player.vel = Vec3.new(player.vel.v[0], 0, player.vel.v[2]);
        player.ground = true;
    }
}

fn checkCollision(player: anytype, world: anytype) bool {
    const half = Vec3.scale(player.size, 0.5);
    const bbox = BBox{ .min = Vec3.sub(player.pos, half), .max = Vec3.add(player.pos, half) };
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
