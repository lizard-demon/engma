const std = @import("std");
const sokol = @import("sokol");
const quake = @import("../physics/quake.zig");
const rocket = @import("../weapons/rocket.zig");

pub const Audio = struct {
    pub fn init(_: std.mem.Allocator) Audio {
        sokol.audio.setup(.{
            .sample_rate = 44100,
            .num_channels = 2,
            .buffer_frames = 1024,
            .stream_cb = callback,
        });
        return .{};
    }

    pub fn deinit(_: *Audio, _: std.mem.Allocator) void {
        if (sokol.audio.isvalid()) sokol.audio.shutdown();
    }

    pub fn tick(_: *Audio, _: f32) void {}
};

fn callback(buffer: [*c]f32, num_frames: i32, num_channels: i32) callconv(.c) void {
    const frames = @as(usize, @intCast(num_frames));
    const channels = @as(usize, @intCast(num_channels));

    for (0..frames) |i| {
        // Mix quake physics audio and weapon explosion audio
        const quake_sample = quake.generateAudioSample();
        const explosion_sample = rocket.generateExplosionAudio();
        const mixed_sample = @max(-1.0, @min(1.0, quake_sample + explosion_sample));

        for (0..channels) |ch| {
            buffer[i * channels + ch] = mixed_sample;
        }
    }
}
