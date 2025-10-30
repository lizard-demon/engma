// Hot-reloadable plugin interface
const std = @import("std");
const engine = @import("mod.zig");
const sokol = @import("sokol");

const Config = struct {
    pub const World = engine.world.greedy;
    pub const Gfx = engine.lib.render(engine.shader.cube);
    pub const Body = engine.physics.quake;
    pub const Keys = engine.lib.input;
};

var game_engine: engine.Engine(Config) = undefined;
var reload_requested: bool = false;

fn initEngine() void {
    sokol.gfx.setup(.{ .environment = sokol.glue.environment() });
    sokol.imgui.setup(.{});
    game_engine = engine.Engine(Config).init();
}

fn deinitEngine() void {
    game_engine.deinit();
    sokol.imgui.shutdown();
    sokol.gfx.shutdown();
}

fn handleEvent(e: sokol.app.Event) void {
    if (e.type == .KEY_DOWN and e.key_code == .R) {
        reload_requested = true;
        return;
    }
    game_engine.event(e);
}

// Plugin interface
export fn plug_pre_reload() *anyopaque {
    return @ptrCast(&game_engine);
}

export fn plug_post_reload(state: *anyopaque) void {
    const saved_engine: *engine.Engine(Config) = @ptrCast(@alignCast(state));
    game_engine = saved_engine.*;
}

// Host interface
export fn plug_sapp_run(_: ?*anyopaque) void {
    sokol.app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = 800,
        .height = 600,
        .window_title = "Hot-Reloadable Meta-Engine (Press R to reload)",
    });
}

export fn init() void {
    initEngine();
    std.log.info("Hot-reloadable engine initialized! Press R to reload", .{});
}

export fn frame() void {
    game_engine.tick();
    game_engine.draw();

    if (reload_requested) {
        reload_requested = false;
        std.log.info("PLUGIN: Reload requested by user", .{});
    }
}

export fn cleanup() void {
    deinitEngine();
    std.log.info("PLUGIN: Engine deinitialized", .{});
}

export fn event(e: [*c]const sokol.app.Event) void {
    handleEvent(e.*);
}
