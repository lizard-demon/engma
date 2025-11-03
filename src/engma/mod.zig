const std = @import("std");

pub const lib = struct {
    pub const math = @import("lib/math.zig");
    pub const input = @import("lib/input.zig").Keys;
    pub const render = @import("lib/render.zig").Gfx;
    pub const audio = @import("lib/audio.zig").Audio;
};

pub const world = struct {
    pub const voxel = @import("world/voxel.zig").World;
    pub const greedy = @import("world/greedy.zig").World;
};

pub const physics = struct {
    pub const quake = @import("physics/quake.zig").Player;
    pub const basic = @import("physics/basic.zig").Player;
};

pub const shader = struct {
    pub const cube = @import("shader/cube/mod.zig");
};

pub fn Engine(comptime Config: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        world: Config.World,
        gfx: Config.Gfx,
        body: Config.Body,
        keys: Config.Keys,
        audio: Config.Audio,
        dt: f32,

        pub fn init(allocator: std.mem.Allocator) Self {
            var engine = Self{
                .allocator = allocator,
                .world = undefined,
                .gfx = undefined,
                .body = undefined,
                .keys = undefined,
                .audio = undefined,
                .dt = 0.016,
            };

            // Initialize all modules with access to the entire engine state
            engine.world = Config.World.init(&engine);
            engine.gfx = Config.Gfx.init(&engine);
            engine.body = Config.Body.init(&engine);
            engine.keys = Config.Keys.init(&engine);
            engine.audio = Config.Audio.init(&engine);

            return engine;
        }

        pub fn tick(self: *Self) void {
            self.dt = self.gfx.getDeltaTime(self);
            self.keys.tick(self);
            self.world.tick(self);
            self.audio.tick(self);
            self.body.tick(self);
            self.body.handleMovement(self);
        }

        pub fn draw(self: *Self) void {
            self.gfx.draw(self);
        }

        pub fn event(self: *Self, e: anytype) void {
            self.keys.event(self, e);
            if (e.type == .MOUSE_MOVE and self.keys.locked) {
                self.body.event(self, e);
            }
        }

        pub fn deinit(self: *Self) void {
            self.world.deinit(self);
            self.audio.deinit(self);
            self.gfx.deinit(self);
            self.body.deinit(self);
            self.keys.deinit(self);
        }
    };
}
