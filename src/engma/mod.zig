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

pub fn Engine(comptime config: anytype) type {
    const ConfigType = @TypeOf(config);
    const fields = @typeInfo(ConfigType).@"struct".fields;

    // Create a state type that holds instances plus allocator and dt
    const StateType = blk: {
        var state_fields: [fields.len + 2]std.builtin.Type.StructField = undefined;

        // Add allocator field
        state_fields[0] = .{
            .name = "allocator",
            .type = std.mem.Allocator,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(std.mem.Allocator),
        };

        // Add dt field
        state_fields[1] = .{
            .name = "dt",
            .type = f32,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(f32),
        };

        // Add module fields
        for (fields, 2..) |field, i| {
            const ModuleType = @field(config, field.name);
            state_fields[i] = .{
                .name = field.name,
                .type = ModuleType,
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = @alignOf(ModuleType),
            };
        }
        break :blk @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = state_fields[0 .. fields.len + 2],
                .decls = &.{},
                .is_tuple = false,
            },
        });
    };

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        dt: f32,
        state: StateType,

        pub fn init(allocator: std.mem.Allocator) Self {
            var engine = Self{
                .allocator = allocator,
                .dt = 0.016,
                .state = undefined,
            };

            // Initialize state fields
            engine.state.allocator = allocator;
            engine.state.dt = 0.016;

            // Initialize all modules with just allocator
            inline for (fields) |field| {
                const ModuleType = @field(config, field.name);
                @field(engine.state, field.name) = ModuleType.init(allocator);
            }

            return engine;
        }

        pub fn tick(self: *Self) void {
            // Create a state instance with the current state
            var state_instance = self.state;
            state_instance.allocator = self.allocator;
            state_instance.dt = self.dt;

            // Update delta time from graphics module if available
            inline for (fields) |field| {
                const module = &@field(state_instance, field.name);
                if (@hasDecl(@TypeOf(module.*), "getDeltaTime")) {
                    self.dt = module.getDeltaTime(state_instance);
                    state_instance.dt = self.dt;
                    break;
                }
            }

            // Call tick on all modules generically
            inline for (fields) |field| {
                @field(state_instance, field.name).tick(state_instance);
            }

            // Copy back the modified state
            self.state = state_instance;
        }

        pub fn draw(self: *Self) void {
            // Create a state instance with the current state
            var state_instance = self.state;
            state_instance.allocator = self.allocator;
            state_instance.dt = self.dt;

            // Call draw on all modules generically
            inline for (fields) |field| {
                @field(state_instance, field.name).draw(state_instance);
            }

            // Copy back the modified state
            self.state = state_instance;
        }

        pub fn event(self: *Self, e: anytype) void {
            // Create a state instance with the current state
            var state_instance = self.state;
            state_instance.allocator = self.allocator;
            state_instance.dt = self.dt;

            // Call event on all modules generically
            inline for (fields) |field| {
                @field(state_instance, field.name).event(state_instance, e);
            }

            // Copy back the modified state
            self.state = state_instance;
        }

        pub fn deinit(self: *Self) void {
            // Create a state instance with the current state
            var state_instance = self.state;
            state_instance.allocator = self.allocator;
            state_instance.dt = self.dt;

            // Call deinit on all modules generically
            inline for (fields) |field| {
                @field(state_instance, field.name).deinit(state_instance);
            }

            // Copy back the modified state
            self.state = state_instance;
        }
    };
}
