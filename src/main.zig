const std = @import("std");
const engma = @import("engma");
const sokol = @import("sokol");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Engine = struct {
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
    fn call(self: *Engine, comptime method: []const u8) void {
        inline for (@typeInfo(@TypeOf(self.systems)).@"struct".fields) |field| {
            @call(.auto, @field(@TypeOf(@field(self.systems, field.name)), method), .{&@field(self.systems, field.name)} ++ .{self.*});
        }
    }
};

var engine: Engine = undefined;

export fn init() void {
    engine.allocator = gpa.allocator();
    engine.dt = 0.016;
    engine.call("init");
}

export fn frame() void {
    engine.dt = @floatCast(sokol.app.frameDuration());
    engine.call("tick");
    engine.call("draw");
}

export fn cleanup() void {
    engine.call("deinit");

    _ = gpa.deinit();
    sokol.imgui.shutdown();
    sokol.gfx.shutdown();
}

export fn event(e: [*c]const sokol.app.Event) void {
    inline for (@typeInfo(@TypeOf(engine.systems)).@"struct".fields) |field| {
        @call(.auto, @field(@TypeOf(@field(engine.systems, field.name)), "event"), .{&@field(engine.systems, field.name)} ++ .{ engine, e.* });
    }
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
