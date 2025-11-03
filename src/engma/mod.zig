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

    // Create a state type that holds instances instead of types
    const StateType = blk: {
        var state_fields: [fields.len]std.builtin.Type.StructField = undefined;
        for (fields, 0..) |field, i| {
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
                .fields = state_fields[0..fields.len],
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

            // Initialize all modules with just allocator
            inline for (fields) |field| {
                const ModuleType = @field(config, field.name);
                @field(engine.state, field.name) = ModuleType.init(allocator);
            }

            return engine;
        }

        pub fn tick(self: *Self) void {
            // Update delta time from graphics module if available
            inline for (fields) |field| {
                const module = &@field(self.state, field.name);
                if (@hasDecl(@TypeOf(module.*), "getDeltaTime")) {
                    self.dt = module.getDeltaTime(self.allocator, self);
                    break;
                }
            }

            // Call tick on all modules generically
            inline for (fields) |field| {
                @field(self.state, field.name).tick(self.allocator, self);
            }
        }

        pub fn draw(self: *Self) void {
            // Call draw on all modules generically
            inline for (fields) |field| {
                @field(self.state, field.name).draw(self.allocator, self);
            }
        }

        pub fn event(self: *Self, e: anytype) void {
            // Call event on all modules generically
            inline for (fields) |field| {
                @field(self.state, field.name).event(self.allocator, self, e);
            }
        }

        pub fn deinit(self: *Self) void {
            // Call deinit on all modules generically
            inline for (fields) |field| {
                @field(self.state, field.name).deinit(self.allocator, self);
            }
        }
    };
}
