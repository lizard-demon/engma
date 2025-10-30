// Hot-swappable meta-engine - elegant runtime polymorphism
const std = @import("std");
const engine = @import("mod.zig");

// Player state preservation
const State = struct {
    pos: engine.lib.math.Vec,
    vel: engine.lib.math.Vec,
    yaw: f32,
    pitch: f32,
    ground: bool,
    prev_ground: bool,
    crouch: bool,
};

// Engine configurations - add new ones here
const Configs = [_]type{ GreedyConfig, VoxelConfig, EmptyConfig };
const Names = [_][]const u8{ "greedy", "voxel", "empty" };

pub const HotEngine = struct {
    allocator: std.mem.Allocator,
    engine: *anyopaque,
    config_index: usize,
    swapping: bool,
    last_swap: i64,

    const COOLDOWN_MS = 100;

    pub fn init(allocator: std.mem.Allocator) !HotEngine {
        const eng = try allocator.create(engine.Engine(Configs[0]));
        eng.* = engine.Engine(Configs[0]).init();

        return HotEngine{
            .allocator = allocator,
            .engine = eng,
            .config_index = 0,
            .swapping = false,
            .last_swap = 0,
        };
    }

    pub fn tick(self: *HotEngine) void {
        self.call("tick", .{});
    }

    pub fn draw(self: *HotEngine) void {
        self.call("draw", .{});
    }

    pub fn event(self: *HotEngine, e: anytype) void {
        if (e.type == .KEY_DOWN and e.key_code == .F5) {
            const now = std.time.milliTimestamp();
            if (!self.swapping and now - self.last_swap >= COOLDOWN_MS) {
                self.swap() catch |err| std.log.err("Swap failed: {}", .{err});
            }
            return;
        }
        self.call("event", .{e});
    }

    pub fn deinit(self: *HotEngine) void {
        self.call("deinit", .{});
        self.destroyCurrent();
    }

    // Generic function call dispatcher
    fn call(self: *HotEngine, comptime func_name: []const u8, args: anytype) void {
        switch (self.config_index) {
            inline 0...Configs.len - 1 => |i| {
                const eng: *engine.Engine(Configs[i]) = @ptrCast(@alignCast(self.engine));
                if (comptime std.mem.eql(u8, func_name, "tick")) {
                    eng.tick();
                } else if (comptime std.mem.eql(u8, func_name, "draw")) {
                    eng.draw();
                } else if (comptime std.mem.eql(u8, func_name, "event")) {
                    eng.event(args[0]);
                } else if (comptime std.mem.eql(u8, func_name, "deinit")) {
                    eng.deinit();
                }
            },
            else => unreachable,
        }
    }

    // Hot-swap to next configuration
    fn swap(self: *HotEngine) !void {
        self.swapping = true;
        defer {
            self.swapping = false;
            self.last_swap = std.time.milliTimestamp();
        }

        // Preserve state
        const state = self.extractState();

        // Destroy current engine
        self.call("deinit", .{});
        self.destroyCurrent();

        // Cycle to next config
        self.config_index = (self.config_index + 1) % Configs.len;

        // Create new engine
        switch (self.config_index) {
            inline 0...Configs.len - 1 => |i| {
                const new_engine = try self.allocator.create(engine.Engine(Configs[i]));
                new_engine.* = engine.Engine(Configs[i]).init();
                self.engine = new_engine;
            },
            else => unreachable,
        }

        // Restore state
        self.restoreState(state);

        std.log.info("Swapped to {s} world", .{Names[self.config_index]});
    }

    // Extract player state from current engine
    fn extractState(self: *HotEngine) State {
        switch (self.config_index) {
            inline 0...Configs.len - 1 => |i| {
                const eng: *engine.Engine(Configs[i]) = @ptrCast(@alignCast(self.engine));
                return State{
                    .pos = eng.body.pos,
                    .vel = eng.body.vel,
                    .yaw = eng.body.yaw,
                    .pitch = eng.body.pitch,
                    .ground = eng.body.ground,
                    .prev_ground = eng.body.prev_ground,
                    .crouch = eng.body.crouch,
                };
            },
            else => unreachable,
        }
    }

    // Restore player state to new engine
    fn restoreState(self: *HotEngine, state: State) void {
        switch (self.config_index) {
            inline 0...Configs.len - 1 => |i| {
                const eng: *engine.Engine(Configs[i]) = @ptrCast(@alignCast(self.engine));
                eng.body.pos = state.pos;
                eng.body.vel = state.vel;
                eng.body.yaw = state.yaw;
                eng.body.pitch = state.pitch;
                eng.body.ground = state.ground;
                eng.body.prev_ground = state.prev_ground;
                eng.body.crouch = state.crouch;
            },
            else => unreachable,
        }
    }

    // Destroy current engine instance
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

// Configuration types
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
