// Hot-swappable meta-engine demo - press F5 to swap implementations at runtime
const std = @import("std");
const engine = @import("engine");
const hot = engine.hot;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var game_engine: hot.HotEngine = undefined;

export fn init() void {
    const allocator = gpa.allocator();

    // Initialize graphics context once globally
    const sokol = @import("sokol");
    const sg = sokol.gfx;
    const simgui = sokol.imgui;
    sg.setup(.{ .environment = sokol.glue.environment() });
    simgui.setup(.{});

    // Start with greedy meshed world
    game_engine = hot.HotEngine.init(allocator) catch |err| {
        std.log.err("Failed to initialize hot engine: {}", .{err});
        return;
    };

    std.log.info("Hot-swappable engine initialized! Press F5 to swap implementations.", .{});
}

export fn frame() void {
    game_engine.tick();
    game_engine.draw();
}

export fn cleanup() void {
    game_engine.deinit();

    // Shutdown graphics context once globally
    const sokol = @import("sokol");
    const sg = sokol.gfx;
    const simgui = sokol.imgui;
    simgui.shutdown();
    sg.shutdown();

    _ = gpa.deinit();
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
        .window_title = "Hot-Swappable Meta-Engine (F5 to swap)",
    });
}
