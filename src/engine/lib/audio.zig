// Ultra-minimal audio system with jump sounds
const std = @import("std");
const sokol = @import("sokol");

var jump_time: f32 = 0;
var jump_phase: f32 = 0;
var land_time: f32 = 0;
var land_phase: f32 = 0;

pub const Audio = struct {
    pub fn init() Audio {
        sokol.audio.setup(.{
            .sample_rate = 44100,
            .num_channels = 2,
            .buffer_frames = 1024,
            .stream_cb = callback,
        });
        return .{};
    }

    pub fn deinit(self: *Audio) void {
        _ = self;
        if (sokol.audio.isvalid()) sokol.audio.shutdown();
    }

    pub fn jump(self: *Audio) void {
        _ = self;
        jump_time = 0.15;
        jump_phase = 0;
    }

    pub fn land(self: *Audio) void {
        _ = self;
        land_time = 0.08;
        land_phase = 0;
    }
};

fn callback(buffer: [*c]f32, num_frames: i32, num_channels: i32) callconv(.c) void {
    const frames = @as(usize, @intCast(num_frames));
    const channels = @as(usize, @intCast(num_channels));
    const sample_rate: f32 = 44100.0;
    const dt = 1.0 / sample_rate;

    for (0..frames) |i| {
        var sample: f32 = 0;

        // Jump sound: frequency sweep
        if (jump_time > 0) {
            const progress = 1.0 - (jump_time / 0.15);
            const frequency = 220.0 + (440.0 - 220.0) * progress;
            const envelope = @exp(-progress * 8.0);
            sample += @sin(jump_phase * 2.0 * std.math.pi) * envelope * 0.3;
            jump_phase += frequency / sample_rate;
            if (jump_phase >= 1.0) jump_phase -= 1.0;
            jump_time -= dt;
        }

        // Land sound: falling frequency with noise
        if (land_time > 0) {
            const progress = 1.0 - (land_time / 0.08);
            const frequency = 150.0 + (80.0 - 150.0) * progress;
            const envelope = @exp(-progress * 12.0);
            const noise = @sin(land_phase * 13.7) * 0.1;
            sample += (@sin(land_phase * 2.0 * std.math.pi) + noise) * envelope * 0.2;
            land_phase += frequency / sample_rate;
            if (land_phase >= 1.0) land_phase -= 1.0;
            land_time -= dt;
        }

        // Write to all channels
        for (0..channels) |ch| {
            buffer[i * channels + ch] = sample;
        }
    }
}
