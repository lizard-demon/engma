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
    pub const wire = @import("shader/wire/mod.zig");
    pub const cube = @import("shader/cube/mod.zig");
};

pub fn Engine(comptime Config: type) type {
    return struct {
        world: Config.World,
        gfx: Config.Gfx,
        body: Config.Body,
        keys: Config.Keys,
        audio: Config.Audio,
        dt: f32,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{
                .world = Config.World.init(allocator),
                .gfx = Config.Gfx.init(allocator),
                .body = Config.Body.init(allocator),
                .keys = Config.Keys.init(allocator),
                .audio = Config.Audio.init(allocator),
                .dt = 0.016,
            };
        }

        pub fn tick(self: *@This()) void {
            self.dt = self.gfx.getDeltaTime();
            self.keys.tick(self.dt);
            self.world.tick(self.dt);
            self.audio.tick(self.dt);
            self.body.tick(self.dt);
            self.body.handleMovement(&self.keys, &self.world, &self.audio, self.dt);
        }

        pub fn draw(self: *@This()) void {
            self.gfx.draw(&self.world, self.body.view());
        }

        pub fn event(self: *@This(), e: anytype) void {
            self.keys.event(e);
            if (e.type == .MOUSE_MOVE and self.keys.locked) {
                self.body.event(e);
            }
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.world.deinit(allocator);
            self.audio.deinit(allocator);
            self.gfx.deinit(allocator);
            self.body.deinit(allocator);
            self.keys.deinit(allocator);
        }
    };
}
