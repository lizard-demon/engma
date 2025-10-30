// Hot-reloadable Meta-Engine - same as main.zig but for hot reloading
const std = @import("std");
const engine = @import("engine");

const world = engine.world;
const phys = engine.physics;
const lib = engine.lib;
const shaders = engine.shader;

const Config = struct {
    pub const World = world.greedy;
    pub const Gfx = lib.render(shaders.cube);
    pub const Body = phys.quake;
    pub const Keys = lib.input;
};
var game_engine: engine.Engine(Config) = undefined;

export fn init() void {
    game_engine = engine.Engine(Config).init();
}

export fn frame() void {
    game_engine.tick();
    game_engine.draw();
}

export fn cleanup() void {
    game_engine.deinit();
    // Shutdown graphics context for regular (non-hot-swap) mode
    lib.render(shaders.cube).shutdown();
}

export fn event(e: [*c]const @import("sokol").app.Event) void {
    game_engine.event(e.*);
}

pub fn main() void {
    const sapp = @import("sokol").app;
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = 800,
        .height = 600,
        .window_title = "Hot-Reloadable Meta-Engine",
    });
}
