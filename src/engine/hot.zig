// Hot-swappable meta-engine - simplified runtime polymorphism
const std = @import("std");
const engine = @import("mod.zig");

// Simple hot-swap demo - just swap between world implementations
pub const HotEngine = struct {
    allocator: std.mem.Allocator,
    current_engine: *anyopaque,
    engine_type: EngineType,

    const EngineType = enum { greedy, voxel, empty };

    pub fn init(allocator: std.mem.Allocator) !HotEngine {
        // Start with greedy config
        const greedy_engine = try allocator.create(engine.Engine(GreedyConfig));
        greedy_engine.* = engine.Engine(GreedyConfig).init();

        return HotEngine{
            .allocator = allocator,
            .current_engine = greedy_engine,
            .engine_type = .greedy,
        };
    }

    pub fn tick(self: *HotEngine) void {
        switch (self.engine_type) {
            .greedy => {
                const eng: *engine.Engine(GreedyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.tick();
            },
            .voxel => {
                const eng: *engine.Engine(VoxelConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.tick();
            },
            .empty => {
                const eng: *engine.Engine(EmptyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.tick();
            },
        }
    }

    pub fn draw(self: *HotEngine) void {
        switch (self.engine_type) {
            .greedy => {
                const eng: *engine.Engine(GreedyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.draw();
            },
            .voxel => {
                const eng: *engine.Engine(VoxelConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.draw();
            },
            .empty => {
                const eng: *engine.Engine(EmptyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.draw();
            },
        }
    }

    pub fn event(self: *HotEngine, e: anytype) void {
        // Handle hot-swap key (F5)
        if (e.type == .KEY_DOWN and e.key_code == .F5) { // F5
            self.hotSwap() catch |err| {
                std.log.err("Hot-swap failed: {}", .{err});
            };
            return;
        }

        switch (self.engine_type) {
            .greedy => {
                const eng: *engine.Engine(GreedyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.event(e);
            },
            .voxel => {
                const eng: *engine.Engine(VoxelConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.event(e);
            },
            .empty => {
                const eng: *engine.Engine(EmptyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.event(e);
            },
        }
    }

    pub fn deinit(self: *HotEngine) void {
        switch (self.engine_type) {
            .greedy => {
                const eng: *engine.Engine(GreedyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.deinit();
                self.allocator.destroy(eng);
            },
            .voxel => {
                const eng: *engine.Engine(VoxelConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.deinit();
                self.allocator.destroy(eng);
            },
            .empty => {
                const eng: *engine.Engine(EmptyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.deinit();
                self.allocator.destroy(eng);
            },
        }
    }

    // Hot-swap between different world implementations
    pub fn hotSwap(self: *HotEngine) !void {
        std.log.info("Hot-swapping world implementation...", .{});

        // Deinit current engine
        self.deinitCurrent();

        // Cycle to next implementation
        const next_type: EngineType = switch (self.engine_type) {
            .greedy => .voxel,
            .voxel => .empty,
            .empty => .greedy,
        };

        // Create new engine
        switch (next_type) {
            .greedy => {
                const new_engine = try self.allocator.create(engine.Engine(GreedyConfig));
                new_engine.* = engine.Engine(GreedyConfig).init();
                self.current_engine = new_engine;
                std.log.info("Swapped to greedy meshed world", .{});
            },
            .voxel => {
                const new_engine = try self.allocator.create(engine.Engine(VoxelConfig));
                new_engine.* = engine.Engine(VoxelConfig).init();
                self.current_engine = new_engine;
                std.log.info("Swapped to voxel world", .{});
            },
            .empty => {
                const new_engine = try self.allocator.create(engine.Engine(EmptyConfig));
                new_engine.* = engine.Engine(EmptyConfig).init();
                self.current_engine = new_engine;
                std.log.info("Swapped to empty world", .{});
            },
        }

        self.engine_type = next_type;
    }

    fn deinitCurrent(self: *HotEngine) void {
        switch (self.engine_type) {
            .greedy => {
                const eng: *engine.Engine(GreedyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.deinit();
                self.allocator.destroy(eng);
            },
            .voxel => {
                const eng: *engine.Engine(VoxelConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.deinit();
                self.allocator.destroy(eng);
            },
            .empty => {
                const eng: *engine.Engine(EmptyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.deinit();
                self.allocator.destroy(eng);
            },
        }
    }
};

// Configuration types for hot-swapping
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
