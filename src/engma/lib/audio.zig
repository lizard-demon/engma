const std = @import("std");
const sokol = @import("sokol");

const MAX_SOUNDS = 8;

const Sound = struct {
    time: f32,
    phase: f32,
    duration: f32,
    frequency_start: f32,
    frequency_end: f32,
    envelope_decay: f32,
    volume: f32,
    noise: f32,
};

var sounds: [MAX_SOUNDS]Sound = [_]Sound{.{
    .time = 0,
    .phase = 0,
    .duration = 0,
    .frequency_start = 0,
    .frequency_end = 0,
    .envelope_decay = 0,
    .volume = 0,
    .noise = 0,
}} ** MAX_SOUNDS;

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

    pub fn playSound(
        _: Audio,
        duration: f32,
        frequency_start: f32,
        frequency_end: f32,
        envelope_decay: f32,
        volume: f32,
        noise: f32,
    ) void {
        // Find an available sound slot
        for (&sounds) |*sound| {
            if (sound.time <= 0) {
                sound.* = .{
                    .time = duration,
                    .phase = 0,
                    .duration = duration,
                    .frequency_start = frequency_start,
                    .frequency_end = frequency_end,
                    .envelope_decay = envelope_decay,
                    .volume = volume,
                    .noise = noise,
                };
                break;
            }
        }
    }
};

fn callback(buffer: [*c]f32, num_frames: i32, num_channels: i32) callconv(.c) void {
    const frames = @as(usize, @intCast(num_frames));
    const channels = @as(usize, @intCast(num_channels));
    const dt = 1.0 / 44100.0;

    for (0..frames) |i| {
        var sample: f32 = 0.0;

        for (&sounds) |*sound| {
            if (sound.time > 0.0) {
                const progress = 1.0 - (sound.time / sound.duration);
                const frequency = sound.frequency_start + (sound.frequency_end - sound.frequency_start) * progress;
                const envelope = @exp(-progress * sound.envelope_decay);
                const noise_sample = if (sound.noise > 0) @sin(sound.phase * 13.7) * sound.noise else 0;

                sample += (@sin(sound.phase * 2.0 * std.math.pi) + noise_sample) * envelope * sound.volume;
                sound.phase += frequency / 44100.0;
                sound.phase = @mod(sound.phase, 1.0);
                sound.time = @max(0.0, sound.time - dt);
            }
        }

        sample = @max(-1.0, @min(1.0, sample));
        for (0..channels) |ch| {
            buffer[i * channels + ch] = sample;
        }
    }
}
