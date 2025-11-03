const std = @import("std");
const engma = @import("engma");
const sokol = @import("sokol");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const State = struct {
    allocator: std.mem.Allocator,
    dt: f32,
    systems: struct {
        world: engma.world.greedy,
        gfx: engma.lib.render(engma.shader.cube),
        body: engma.physics.quake,
        keys: engma.lib.input,
        audio: engma.lib.audio,
        debug: engma.lib.debug,
    },
    fn call(systems: anytype, comptime method: []const u8, args: anytype) void {
        inline for (@typeInfo(@TypeOf(systems.*)).@"struct".fields) |field| {
            @call(.auto, @field(@TypeOf(@field(systems, field.name)), method), .{&@field(systems, field.name)} ++ args);
        }
    }
};

var state: State = undefined;

export fn init() void {
    // Initialize state fields
    state.allocator = gpa.allocator();
    state.dt = 0.016;

    // Initialize all systems
    inline for (@typeInfo(@TypeOf(state.systems)).@"struct".fields) |field| {
        @field(state.systems, field.name) = field.type.init(state.allocator);
    }
}

export fn frame() void {
    // Update delta time
    state.dt = @floatCast(sokol.app.frameDuration());

    // Tick and draw all systems
    State.call(&state.systems, "tick", .{state});
    State.call(&state.systems, "draw", .{state});
}

export fn cleanup() void {
    // Deinitialize all systems
    State.call(&state.systems, "deinit", .{state});

    _ = gpa.deinit();
    sokol.imgui.shutdown();
    sokol.gfx.shutdown();
}

export fn event(e: [*c]const sokol.app.Event) void {
    // Handle events for all systems
    State.call(&state.systems, "event", .{ state, e.* });
}

pub fn main() void {
    sokol.app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = 800,
        .height = 600,
        .window_title = "Engma",
    });
}
