// Live development hot-swapping - simple and fast
const std = @import("std");
const engine = @import("mod.zig");

// Available configurations for live development
const Configs = [_]type{ GreedyConfig, VoxelConfig, EmptyConfig };
const Names = [_][]const u8{ "greedy", "voxel", "empty" };

pub const HotEngine = struct {
    allocator: std.mem.Allocator,
    engine: *anyopaque,
    config_index: usize,

    pub fn init(allocator: std.mem.Allocator) !HotEngine {
        const eng = try allocator.create(engine.Engine(Configs[0]));
        eng.* = engine.Engine(Configs[0]).init();

        return HotEngine{
            .allocator = allocator,
            .engine = eng,
            .config_index = 0,
        };
    }

    pub fn tick(self: *HotEngine) void {
        self.call("tick");
    }

    pub fn draw(self: *HotEngine) void {
        self.call("draw");
    }

    pub fn event(self: *HotEngine, e: anytype) void {
        // F5 = instant hot-swap for live development
        if (e.type == .KEY_DOWN and e.key_code == .F5) {
            self.swap() catch |err| std.log.err("Swap failed: {}", .{err});
            return;
        }
        self.callWithArg("event", e);
    }

    pub fn deinit(self: *HotEngine) void {
        self.call("deinit");
        self.destroyCurrent();
    }

    // Simple function dispatcher
    fn call(self: *HotEngine, comptime func_name: []const u8) void {
        switch (self.config_index) {
            inline 0...Configs.len - 1 => |i| {
                const eng: *engine.Engine(Configs[i]) = @ptrCast(@alignCast(self.engine));
                if (comptime std.mem.eql(u8, func_name, "tick")) {
                    eng.tick();
                } else if (comptime std.mem.eql(u8, func_name, "draw")) {
                    eng.draw();
                } else if (comptime std.mem.eql(u8, func_name, "deinit")) {
                    eng.deinit();
                }
            },
            else => unreachable,
        }
    }

    fn callWithArg(self: *HotEngine, comptime func_name: []const u8, arg: anytype) void {
        switch (self.config_index) {
            inline 0...Configs.len - 1 => |i| {
                const eng: *engine.Engine(Configs[i]) = @ptrCast(@alignCast(self.engine));
                if (comptime std.mem.eql(u8, func_name, "event")) {
                    eng.event(arg);
                }
            },
            else => unreachable,
        }
    }

    // Instant hot-swap for live development
    fn swap(self: *HotEngine) !void {
        // Clean shutdown of current engine
        self.call("deinit");
        self.destroyCurrent();

        // Cycle to next config
        self.config_index = (self.config_index + 1) % Configs.len;

        // Create new engine instantly
        switch (self.config_index) {
            inline 0...Configs.len - 1 => |i| {
                const new_engine = try self.allocator.create(engine.Engine(Configs[i]));
                new_engine.* = engine.Engine(Configs[i]).init();
                self.engine = new_engine;
            },
            else => unreachable,
        }

        std.log.info("Live swap: {s} world", .{Names[self.config_index]});
    }

    fn destroyCurrent(self: *HotEngine) void {
        switch (self.config_index) {
            inline 0...Configs.len - 1 => |i| {
                const eng: *engine.Engine(Configs[i]) = @ptrCast(@alignCast(self.engine));
                self.allocator.destroy(eng);
            },
            else => unreachable,
        }
    }
};

// Live development configurations
const GreedyConfig = struct {
    pub const World = engine.world.greedy;
    pub const Gfx = engine.lib.render(engine.shader.cube);
    pub const Body = engine.physics.quake;
    pub const Keys = engine.lib.input;
};

const VoxelConfig = struct {
    pub const World = engine.world.voxel;
    pub const Gfx = engine.lib.render(engine.shader.cube);
    pub const Body = engine.physics.quake;
    pub const Keys = engine.lib.input;
};

const EmptyConfig = struct {
    pub const World = engine.world.empty;
    pub const Gfx = engine.lib.render(engine.shader.cube);
    pub const Body = engine.physics.quake;
    pub const Keys = engine.lib.input;
};
