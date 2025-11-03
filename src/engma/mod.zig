const std = @import("std");

pub const lib = struct {
    pub const math = @import("lib/math.zig");
    pub const input = @import("lib/input.zig").Keys;
    pub const render = @import("lib/render.zig").Gfx;
    pub const audio = @import("lib/audio.zig").Audio;
    pub const debug = @import("lib/debug.zig").Debug;
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

pub fn Engine(comptime StateType: type) type {
    const systems_field = @typeInfo(StateType).@"struct".fields[2]; // systems is the 3rd field
    const SystemsType = systems_field.type;
    const system_fields = @typeInfo(SystemsType).@"struct".fields;

    return struct {
        const Self = @This();

        state: StateType,

        pub fn init(allocator: std.mem.Allocator) Self {
            var engine = Self{
                .state = undefined,
            };

            // Initialize state fields
            engine.state.allocator = allocator;
            engine.state.dt = 0.016;

            // Initialize all systems with just allocator
            inline for (system_fields) |field| {
                @field(engine.state.systems, field.name) = field.type.init(allocator);
            }

            return engine;
        }

        pub fn tick(self: *Self) void {
            // Update delta time from graphics module if available
            inline for (system_fields) |field| {
                const module = &@field(self.state.systems, field.name);
                if (@hasDecl(@TypeOf(module.*), "getDeltaTime")) {
                    self.state.dt = module.getDeltaTime(self.state);
                    break;
                }
            }

            // Call tick on all systems generically
            inline for (system_fields) |field| {
                @field(self.state.systems, field.name).tick(self.state);
            }
        }

        pub fn draw(self: *Self) void {
            // Call draw on all systems generically
            inline for (system_fields) |field| {
                @field(self.state.systems, field.name).draw(self.state);
            }
        }

        pub fn event(self: *Self, e: anytype) void {
            // Call event on all systems generically
            inline for (system_fields) |field| {
                @field(self.state.systems, field.name).event(self.state, e);
            }
        }

        pub fn deinit(self: *Self) void {
            // Call deinit on all systems generically
            inline for (system_fields) |field| {
                @field(self.state.systems, field.name).deinit(self.state);
            }
        }
    };
}
