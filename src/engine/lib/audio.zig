// Ultra-minimal audio system - just the infrastructure
const sokol = @import("sokol");

pub const Audio = struct {
    pub fn init() Audio {
        sokol.audio.setup(.{
            .sample_rate = 44100,
            .num_channels = 2,
            .buffer_frames = 1024,
        });
        return .{};
    }

    pub fn deinit(self: *Audio) void {
        _ = self;
        if (sokol.audio.isvalid()) sokol.audio.shutdown();
    }
};
