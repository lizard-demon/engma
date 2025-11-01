const std = @import("std");
const engma = @import("engma");

const Config = struct {
    pub const World = engma.world.greedy;
    pub const Gfx = engma.lib.render(engma.shader.cube);
    pub const Body = engma.physics.quake;
    pub const Keys = engma.lib.input;
    pub const Audio = engma.lib.audio;
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

    if (gpa.deinit() == .leak) {
        std.log.err("Memory leak detected", .{});
    }

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
