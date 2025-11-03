pub const lib = struct {
    pub const math = @import("lib/math.zig");
    pub const input = @import("lib/input.zig").Keys;
    pub const render = @import("lib/render.zig").Gfx;
    pub const audio = @import("lib/audio/mod.zig").Audio;
    pub const debug = @import("lib/debug.zig").Debug;
};

pub const world = struct {
    pub const voxel = @import("world/voxel.zig").World;
    pub const greedy = @import("world/greedy.zig").World;
};

pub const physics = struct {
    // Legacy physics namespace - use engma.player instead
};

pub const player = struct {
    pub const quake = @import("player/quake/mod.zig").Player;
    pub const basic = @import("player/basic/mod.zig").Player;
};

pub const shader = struct {
    pub const cube = @import("shader/cube/mod.zig");
};
