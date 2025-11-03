const std = @import("std");
const engma = @import("engma");
const sokol = @import("sokol");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Engine = struct {
    allocator: std.mem.Allocator,
    event: sokol.app.Event,
    dt: f32,

    systems: struct {
        world: engma.world.greedy,
        gfx: engma.lib.render(engma.shader.cube),
        body: engma.physics.quake,
        keys: engma.lib.input,
        audio: engma.lib.audio,
        debug: engma.lib.debug,
    },

    fn call(self: *Engine, comptime system: []const u8) void {
        inline for (@typeInfo(@TypeOf(self.systems)).@"struct".fields) |field| {
            @call(.auto, @field(@TypeOf(@field(self.systems, field.name)), system), .{&@field(self.systems, field.name)} ++ .{self.*});
        }
    }
};

var engine: Engine = undefined;

export fn init() void {
    engine.allocator = gpa.allocator();
    engine.dt = 0.016;
    engine.event = undefined;
    engine.call("init");
}

export fn frame() void {
    engine.dt = @floatCast(sokol.app.frameDuration());
    engine.call("tick");
    engine.call("draw");
}

export fn event(e: [*c]const sokol.app.Event) void {
    engine.event = e.*;
    engine.call("event");
}

export fn cleanup() void {
    engine.call("deinit");
    _ = gpa.deinit();
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
