const std = @import("std");
const engma = @import("engma");
const sokol = @import("sokol");

const config = .{
    .World = engma.world.greedy,
    .Gfx = engma.lib.render(engma.shader.cube),
    .Body = engma.physics.quake,
    .Keys = engma.lib.input,
    .Audio = engma.lib.audio,
    .Debug = engma.lib.debug,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var engine: engma.Engine(config) = undefined;

export fn init() void {
    engine = engma.Engine(config).init(gpa.allocator());
}

export fn frame() void {
    engine.tick();
    engine.draw();
}

export fn cleanup() void {
    engine.deinit();
    _ = gpa.deinit();
    sokol.imgui.shutdown();
    sokol.gfx.shutdown();
}

export fn event(e: [*c]const sokol.app.Event) void {
    engine.event(e.*);
}

pub fn main() void {
    sokol.app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = 800,
        .height = 600,
        .window_title = "Meta-Engine",
    });
}
