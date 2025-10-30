// Dynamic library exports for hot-swapping
const std = @import("std");
const engine = @import("mod.zig");
const sokol = @import("sokol");

// Default configuration for hot swapping
const Config = struct {
    pub const World = engine.world.greedy;
    pub const Gfx = engine.lib.render(engine.shader.cube);
    pub const Body = engine.physics.quake;
    pub const Keys = engine.lib.input;
};

var hot_engine: engine.Engine(Config) = undefined;

export fn engine_init() void {
    hot_engine = engine.Engine(Config).init();
    std.log.info("ENGINE: Hot-swappable engine initialized", .{});
}

export fn engine_destroy() void {
    hot_engine.deinit();
    std.log.info("ENGINE: Hot-swappable engine destroyed", .{});
}

export fn engine_pre_reload() *anyopaque {
    return @ptrCast(&hot_engine);
}

export fn engine_post_reload(state: *anyopaque) void {
    const saved_engine: *engine.Engine(Config) = @ptrCast(@alignCast(state));
    hot_engine = saved_engine.*;
    std.log.info("ENGINE: State restored after hot reload", .{});
}

export fn engine_tick() void {
    hot_engine.tick();
}

export fn engine_draw() void {
    hot_engine.draw();
}

export fn engine_event(e: sokol.app.Event) void {
    hot_engine.event(e);
}
