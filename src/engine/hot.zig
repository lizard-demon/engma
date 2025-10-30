// Hot-swappable meta-engine - simplified runtime polymorphism
const std = @import("std");
const engine = @import("mod.zig");
const math = engine.lib.math;

// Player state for preservation across hot-swaps
const PlayerState = struct {
    pos: math.Vec,
    vel: math.Vec,
    yaw: f32,
    pitch: f32,
    ground: bool,
    prev_ground: bool,
    crouch: bool,
};

// Simple hot-swap demo - just swap between world implementations
pub const HotEngine = struct {
    allocator: std.mem.Allocator,
    current_engine: *anyopaque,
    engine_type: EngineType,
    swapping: bool,
    last_swap_time: i64,

    const EngineType = enum { greedy, voxel, empty };
    const SWAP_COOLDOWN_MS = 100; // Minimum 100ms between swaps

    pub fn init(allocator: std.mem.Allocator) !HotEngine {
        // Start with greedy config
        const greedy_engine = try allocator.create(engine.Engine(GreedyConfig));
        greedy_engine.* = engine.Engine(GreedyConfig).init();

        return HotEngine{
            .allocator = allocator,
            .current_engine = greedy_engine,
            .engine_type = .greedy,
            .swapping = false,
            .last_swap_time = 0,
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
        // Handle hot-swap key (F5) with cooldown protection
        if (e.type == .KEY_DOWN and e.key_code == .F5) { // F5
            const current_time = std.time.milliTimestamp();

            // Prevent rapid swapping that could cause crashes
            if (self.swapping) {
                std.log.warn("Hot-swap already in progress, ignoring...", .{});
                return;
            }

            if (current_time - self.last_swap_time < SWAP_COOLDOWN_MS) {
                std.log.warn("Hot-swap cooldown active, wait {}ms", .{SWAP_COOLDOWN_MS - (current_time - self.last_swap_time)});
                return;
            }

            self.hotSwap() catch |err| {
                std.log.err("Hot-swap failed: {}", .{err});
                self.swapping = false; // Reset on error
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
        self.swapping = true;
        defer {
            self.swapping = false;
            self.last_swap_time = std.time.milliTimestamp();
        }

        std.log.info("Hot-swapping world implementation...", .{});

        // Preserve player state before swap
        const player_state = self.extractPlayerState();

        // Deinit current engine safely
        self.deinitCurrent();

        // Cycle to next implementation
        const next_type: EngineType = switch (self.engine_type) {
            .greedy => .voxel,
            .voxel => .empty,
            .empty => .greedy,
        };

        // Create new engine with error handling
        switch (next_type) {
            .greedy => {
                const new_engine = try self.allocator.create(engine.Engine(GreedyConfig));
                errdefer self.allocator.destroy(new_engine);
                new_engine.* = engine.Engine(GreedyConfig).init();
                self.current_engine = new_engine;
                std.log.info("Swapped to greedy meshed world", .{});
            },
            .voxel => {
                const new_engine = try self.allocator.create(engine.Engine(VoxelConfig));
                errdefer self.allocator.destroy(new_engine);
                new_engine.* = engine.Engine(VoxelConfig).init();
                self.current_engine = new_engine;
                std.log.info("Swapped to voxel world", .{});
            },
            .empty => {
                const new_engine = try self.allocator.create(engine.Engine(EmptyConfig));
                errdefer self.allocator.destroy(new_engine);
                new_engine.* = engine.Engine(EmptyConfig).init();
                self.current_engine = new_engine;
                std.log.info("Swapped to empty world", .{});
            },
        }

        self.engine_type = next_type;

        // Restore player state after swap with validation
        self.restorePlayerState(player_state);
    }

    // Extract player state from current engine
    fn extractPlayerState(self: *HotEngine) PlayerState {
        switch (self.engine_type) {
            .greedy => {
                const eng: *engine.Engine(GreedyConfig) = @ptrCast(@alignCast(self.current_engine));
                return PlayerState{
                    .pos = eng.body.pos,
                    .vel = eng.body.vel,
                    .yaw = eng.body.yaw,
                    .pitch = eng.body.pitch,
                    .ground = eng.body.ground,
                    .prev_ground = eng.body.prev_ground,
                    .crouch = eng.body.crouch,
                };
            },
            .voxel => {
                const eng: *engine.Engine(VoxelConfig) = @ptrCast(@alignCast(self.current_engine));
                return PlayerState{
                    .pos = eng.body.pos,
                    .vel = eng.body.vel,
                    .yaw = eng.body.yaw,
                    .pitch = eng.body.pitch,
                    .ground = eng.body.ground,
                    .prev_ground = eng.body.prev_ground,
                    .crouch = eng.body.crouch,
                };
            },
            .empty => {
                const eng: *engine.Engine(EmptyConfig) = @ptrCast(@alignCast(self.current_engine));
                return PlayerState{
                    .pos = eng.body.pos,
                    .vel = eng.body.vel,
                    .yaw = eng.body.yaw,
                    .pitch = eng.body.pitch,
                    .ground = eng.body.ground,
                    .prev_ground = eng.body.prev_ground,
                    .crouch = eng.body.crouch,
                };
            },
        }
    }

    // Restore player state to new engine
    fn restorePlayerState(self: *HotEngine, state: PlayerState) void {
        switch (self.engine_type) {
            .greedy => {
                const eng: *engine.Engine(GreedyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.body.pos = state.pos;
                eng.body.vel = state.vel;
                eng.body.yaw = state.yaw;
                eng.body.pitch = state.pitch;
                eng.body.ground = state.ground;
                eng.body.prev_ground = state.prev_ground;
                eng.body.crouch = state.crouch;
            },
            .voxel => {
                const eng: *engine.Engine(VoxelConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.body.pos = state.pos;
                eng.body.vel = state.vel;
                eng.body.yaw = state.yaw;
                eng.body.pitch = state.pitch;
                eng.body.ground = state.ground;
                eng.body.prev_ground = state.prev_ground;
                eng.body.crouch = state.crouch;
            },
            .empty => {
                const eng: *engine.Engine(EmptyConfig) = @ptrCast(@alignCast(self.current_engine));
                eng.body.pos = state.pos;
                eng.body.vel = state.vel;
                eng.body.yaw = state.yaw;
                eng.body.pitch = state.pitch;
                eng.body.ground = state.ground;
                eng.body.prev_ground = state.prev_ground;
                eng.body.crouch = state.crouch;
            },
        }
    }

    fn deinitCurrent(self: *HotEngine) void {
        // Safe deinitialization

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
