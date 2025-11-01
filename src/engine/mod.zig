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

// Generic data access for modules
const ModuleData = struct {
    world: ?*const anyopaque = null,
    input: ?*const anyopaque = null,
    physics: ?*const anyopaque = null,
    audio: ?*const anyopaque = null,
    render: ?*const anyopaque = null,
};

pub fn Engine(comptime Config: type) type {
    return struct {
        const Self = @This();

        world: Config.World,
        gfx: Config.Gfx,
        body: Config.Body,
        keys: Config.Keys,
        audio: Config.Audio,
        dt: f32,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .world = Config.World.init(allocator),
                .gfx = Config.Gfx.init(allocator),
                .body = Config.Body.init(allocator),
                .keys = Config.Keys.init(allocator),
                .audio = Config.Audio.init(allocator),
                .dt = 0.016, // Default 60fps
            };
        }

        pub fn tick(self: *Self) void {
            // Update delta time from platform
            self.dt = self.gfx.getDeltaTime();

            // All modules tick independently with dt
            self.keys.tick(self.dt);
            self.world.tick(self.dt);
            self.body.tick(self.dt);
            self.audio.tick(self.dt);
            self.gfx.tick(self.dt);
        }

        pub fn draw(self: *Self) void {
            // Get view matrix from physics
            const view = self.body.view();
            // Pass world and view to renderer
            self.gfx.draw(&self.world, view);
        }

        pub fn event(self: *Self, e: anytype) void {
            self.keys.event(e);
            // Only pass mouse events to physics if input is locked
            if (e.type == .MOUSE_MOVE and self.keys.locked) {
                self.body.event(e);
            }
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.world.deinit(allocator);
            self.audio.deinit(allocator);
            self.gfx.deinit(allocator);
            self.body.deinit(allocator);
            self.keys.deinit(allocator);
        }

        // Generic data access for modules
        pub fn getData(self: *const Self, comptime module_name: []const u8) *const anyopaque {
            if (std.mem.eql(u8, module_name, "world")) return &self.world;
            if (std.mem.eql(u8, module_name, "input")) return &self.keys;
            if (std.mem.eql(u8, module_name, "physics")) return &self.body;
            if (std.mem.eql(u8, module_name, "audio")) return &self.audio;
            if (std.mem.eql(u8, module_name, "render")) return &self.gfx;
            @panic("Unknown module");
        }
    };
}
