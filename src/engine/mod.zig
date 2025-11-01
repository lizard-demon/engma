// Core engine module - professional namespace + engine implementation
const std = @import("std");

// Professional meta-engine namespace - direct access to implementations
pub const lib = struct {
    pub const math = @import("lib/math.zig");
    pub const input = @import("lib/input.zig").Keys;
    pub const render = @import("lib/render.zig").Gfx;
    pub const audio = @import("lib/audio.zig").Audio;
};

pub const world = struct {
    pub const voxel = @import("world/voxel.zig").World;
    pub const empty = @import("world/empty.zig").World;
    pub const greedy = @import("world/greedy.zig").World;
};

pub const physics = struct {
    pub const quake = @import("physics/quake.zig").Player;
    pub const simple = @import("physics/simple.zig").Player;
};

pub const shader = struct {
    pub const cube = @import("shader/cube/mod.zig");
};

pub fn Engine(comptime Config: type) type {
    return struct {
        const Self = @This();

        world: Config.World,
        gfx: Config.Gfx,
        body: Config.Body,
        keys: Config.Keys,
        audio: Config.Audio,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .world = Config.World.init(allocator),
                .gfx = Config.Gfx.init(),
                .body = Config.Body.init(),
                .keys = Config.Keys.init(),
                .audio = Config.Audio.init(),
            };
        }

        pub fn tick(self: *Self) void {
            const dt = self.gfx.dt();
            self.keys.tick();
            self.body.tick(&self.world, &self.keys, &self.audio, dt);
        }

        pub fn draw(self: *Self) void {
            const view = self.body.view();
            self.gfx.draw(&self.world, view);
        }

        pub fn event(self: *Self, e: anytype) void {
            self.keys.event(e);
            // Pass mouse events to body
            if (e.type == .MOUSE_MOVE and self.keys.locked) {
                self.body.mouse(e.mouse_dx, e.mouse_dy);
            }
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.world.deinit(allocator);
            self.audio.deinit();
            self.gfx.deinit();
        }
    };
}
