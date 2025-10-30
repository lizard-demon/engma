// Engine as hot-swappable dynamic library
const std = @import("std");
const engine = @import("engine");
const sokol = @import("sokol");

// Engine configuration
const Config = struct {
    pub const World = engine.world.greedy;
    pub const Gfx = engine.lib.render(engine.shader.cube);
    pub const Body = engine.physics.quake;
    pub const Keys = engine.lib.input;
};

var game_engine: engine.Engine(Config) = undefined;

export fn engine_init() void {
    game_engine = engine.Engine(Config).init();
    std.log.info("ENGINE: Hot-swappable engine initialized", .{});
}

export fn engine_destroy() void {
    game_engine.deinit();
    std.log.info("ENGINE: Hot-swappable engine destroyed", .{});
}

export fn engine_pre_reload() *anyopaque {
    // Return engine state for preservation
    return @ptrCast(&game_engine);
}

export fn engine_post_reload(state: *anyopaque) void {
    // Restore engine state
    const saved_engine: *engine.Engine(Config) = @ptrCast(@alignCast(state));
    game_engine = saved_engine.*;
    std.log.info("ENGINE: State restored after hot reload", .{});
}

export fn engine_tick() void {
    game_engine.tick();
}

export fn engine_draw() void {
    game_engine.draw();
}

export fn engine_event(e: sokol.app.Event) void {
    game_engine.event(e);
}
