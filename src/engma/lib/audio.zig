const std = @import("std");
const sokol = @import("sokol");

var jump_time: f32 = 0;
var jump_phase: f32 = 0;
var land_time: f32 = 0;
var land_phase: f32 = 0;

pub const Audio = struct {
    pub fn init(self: *Audio, _: anytype) void {
        sokol.audio.setup(.{
            .sample_rate = 44100,
            .num_channels = 2,
            .buffer_frames = 1024,
            .stream_cb = callback,
        });
        self.* = .{};
    }

    pub fn deinit(_: *Audio, _: anytype) void {
        if (sokol.audio.isvalid()) sokol.audio.shutdown();
    }

    pub fn tick(_: *Audio, _: anytype) void {}
    pub fn draw(_: *Audio, _: anytype) void {}
    pub fn event(_: *Audio, _: anytype) void {}

    pub fn jump(_: Audio) void {
        jump_time = 0.15;
        jump_phase = 0;
    }

    pub fn land(_: Audio) void {
        land_time = 0.08;
        land_phase = 0;
    }
};

fn callback(buffer: [*c]f32, num_frames: i32, num_channels: i32) callconv(.c) void {
    const frames = @as(usize, @intCast(num_frames));
    const channels = @as(usize, @intCast(num_channels));
    const dt = 1.0 / 44100.0;

    for (0..frames) |i| {
        var sample: f32 = 0.0;

        if (jump_time > 0.0) {
            const progress = 1.0 - (jump_time / 0.15);
            const frequency = 220.0 + 220.0 * progress;
            const envelope = @exp(-progress * 8.0);
            sample += @sin(jump_phase * 2.0 * std.math.pi) * envelope * 0.3;
            jump_phase += frequency / 44100.0;
            jump_phase = @mod(jump_phase, 1.0);
            jump_time = @max(0.0, jump_time - dt);
        }

        if (land_time > 0.0) {
            const progress = 1.0 - (land_time / 0.08);
            const frequency = 150.0 - 70.0 * progress;
            const envelope = @exp(-progress * 12.0);
            const noise = @sin(land_phase * 13.7) * 0.1;
            sample += (@sin(land_phase * 2.0 * std.math.pi) + noise) * envelope * 0.2;
            land_phase += frequency / 44100.0;
            land_phase = @mod(land_phase, 1.0);
            land_time = @max(0.0, land_time - dt);
        }

        sample = @max(-1.0, @min(1.0, sample));
        for (0..channels) |ch| {
            buffer[i * channels + ch] = sample;
        }
    }
}
