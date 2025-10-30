// Hot-swappable meta-engine demo - press F5 to swap implementations at runtime
const std = @import("std");
const engine = @import("engine");
const hot = engine.hot;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var game_engine: hot.HotEngine = undefined;

export fn init() void {
    const allocator = gpa.allocator();

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
