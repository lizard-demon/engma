const std = @import("std");
const engma = @import("engma");
const sokol = @import("sokol");

const Config = struct {
    pub const World = engma.world.greedy;
    pub const Gfx = engma.lib.render(engma.shader.cube);
    pub const Body = engma.physics.quake;
    pub const Keys = engma.lib.input;
    pub const Audio = engma.lib.audio;
    pub const Weapons = engma.weapons.rocket;
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var engine: engma.Engine(Config) = undefined;

export fn init() void {
    engine = engma.Engine(Config).init(gpa.allocator());
}

export fn frame() void {
    engine.tick();
    engine.draw();
}

export fn cleanup() void {
    engine.deinit(gpa.allocator());
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
