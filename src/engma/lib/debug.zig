const std = @import("std");

pub const Debug = struct {
    frame_count: u64,
    last_fps_time: f64,
    fps: f32,

    pub fn init(self: *Debug, _: anytype) void {
        self.* = .{
            .frame_count = 0,
            .last_fps_time = 0,
            .fps = 0,
        };
    }

    pub fn deinit(_: *Debug, _: anytype) void {}

    pub fn tick(self: *Debug, state: anytype) void {
        self.frame_count += 1;

        // Calculate FPS every second
        const current_time = @as(f64, @floatFromInt(std.time.milliTimestamp())) / 1000.0;
        if (current_time - self.last_fps_time >= 1.0) {
            self.fps = @as(f32, @floatFromInt(self.frame_count)) / @as(f32, @floatCast(current_time - self.last_fps_time));
            self.frame_count = 0;
            self.last_fps_time = current_time;

            // Print debug info
            std.debug.print("FPS: {d:.1} | Player pos: ({d:.2}, {d:.2}, {d:.2}) | DT: {d:.3}\n", .{ self.fps, state.systems.body.pos.v[0], state.systems.body.pos.v[1], state.systems.body.pos.v[2], state.dt });
        }
    }

    pub fn draw(_: *Debug, _: anytype) void {}
    pub fn event(_: *Debug, _: anytype) void {}
};
