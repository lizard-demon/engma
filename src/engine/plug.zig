// Dynamic library interface following Zig plugin conventions
const std = @import("std");
const engine = @import("mod.zig");
const sokol = @import("sokol");

// Plugin configuration
const Config = struct {
    pub const World = engine.world.greedy;
    pub const Gfx = engine.lib.render(engine.shader.cube);
    pub const Body = engine.physics.quake;
    pub const Keys = engine.lib.input;
};

var game_engine: engine.Engine(Config) = undefined;
var reload_requested: bool = false;

// Standard plugin interface
export fn plug_init() void {
    // Initialize graphics context in plugin
    sokol.gfx.setup(.{ .environment = sokol.glue.environment() });
    sokol.imgui.setup(.{});

    game_engine = engine.Engine(Config).init();
    std.log.info("PLUGIN: Engine initialized", .{});
}

export fn plug_deinit() void {
    game_engine.deinit();

    // Shutdown graphics context in plugin
    sokol.imgui.shutdown();
    sokol.gfx.shutdown();

    std.log.info("PLUGIN: Engine deinitialized", .{});
}

export fn plug_pre_reload() *anyopaque {
    return @ptrCast(&game_engine);
}

export fn plug_post_reload(state: *anyopaque) void {
    const saved_engine: *engine.Engine(Config) = @ptrCast(@alignCast(state));
    game_engine = saved_engine.*;
    std.log.info("PLUGIN: State restored", .{});
}

export fn plug_update() void {
    game_engine.tick();
    game_engine.draw();
}

export fn plug_event(e_ptr: *anyopaque) void {
    const e: *sokol.app.Event = @ptrCast(@alignCast(e_ptr));

    // Check for reload request
    if (e.type == .KEY_DOWN and e.key_code == .R) {
        reload_requested = true;
        return;
    }

    game_engine.event(e.*);
}

// Sokol interface provided to host - simplified approach
export fn plug_sapp_run(desc_ptr: ?*anyopaque) void {
    _ = desc_ptr; // Ignore the passed descriptor for now

    // Just run sokol directly with our own callbacks for simplicity
    sokol.app.run(.{
        .init_cb = plug_host_init,
        .frame_cb = plug_host_frame,
        .cleanup_cb = plug_host_cleanup,
        .event_cb = plug_host_event,
        .width = 800,
        .height = 600,
        .window_title = "Hot-Reloadable Meta-Engine (Press R to reload)",
    });
}

// Internal callbacks that handle both plugin and host logic
export fn plug_host_init() void {
    // Initialize graphics context in plugin
    sokol.gfx.setup(.{ .environment = sokol.glue.environment() });
    sokol.imgui.setup(.{});

    game_engine = engine.Engine(Config).init();
    std.log.info("Hot-reloadable engine initialized! Press R to reload", .{});
}

export fn plug_host_frame() void {
    game_engine.tick();
    game_engine.draw();

    // Check if reload was requested
    if (reload_requested) {
        reload_requested = false;
        std.log.info("PLUGIN: Reload requested by user", .{});
    }
}

export fn plug_host_cleanup() void {
    game_engine.deinit();

    // Shutdown graphics context in plugin
    sokol.imgui.shutdown();
    sokol.gfx.shutdown();

    std.log.info("PLUGIN: Engine deinitialized", .{});
}

export fn plug_host_event(e: [*c]const sokol.app.Event) void {
    const event = e.*;

    // Check for reload request
    if (event.type == .KEY_DOWN and event.key_code == .R) {
        reload_requested = true;
        return;
    }

    game_engine.event(event);
}
