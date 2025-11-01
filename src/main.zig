// Meta-Engine: Brutalist, hyper-minimalist, swappable meta-engine
// Pure abstraction over implementations - based on the architectural genius of the FPS demo
const std = @import("std");
const engma = @import("engma");

const world = engma.world;
const phys = engma.physics;
const lib = engma.lib;
const shaders = engma.shader;

const Config = struct {
    pub const World = world.greedy;
    pub const Gfx = lib.render(shaders.cube);
    pub const Body = phys.quake;
    pub const Keys = lib.input;
    pub const Audio = lib.audio;
};
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var game_engine: engma.Engine(Config) = undefined;

export fn init() void {
    const allocator = gpa.allocator();
    game_engine = engma.Engine(Config).init(allocator);
}

export fn frame() void {
    game_engine.tick();
    game_engine.draw();
}

export fn cleanup() void {
    const allocator = gpa.allocator();
    game_engine.deinit(allocator);
    _ = gpa.deinit();
    // Shutdown graphics context
    const sokol = @import("sokol");
    sokol.imgui.shutdown();
    sokol.gfx.shutdown();
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
        .window_title = "Meta-Engine",
    });
}
