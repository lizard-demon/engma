const std = @import("std");

// Player size configuration
pub const size = struct {
    pub const stand = 1.8;
    pub const crouch = 0.9;
    pub const width = 0.49;
};

// Movement configuration
pub const move = struct {
    pub const speed = 4.0;
    pub const crouch_speed = 2.0;
    pub const air_cap = 0.7;
    pub const accel = 70.0;
    pub const min_len = 0.001;
};

// Physics configuration
pub const phys = struct {
    pub const gravity = 12.0;
    pub const steps = 3;
    pub const ground_thresh = 0.01;
};

// Friction configuration
pub const friction = struct {
    pub const min_speed = 0.1;
    pub const factor = 5.0;
};

// Jump and camera configuration
pub const jump_power = 4.0;
pub const pitch_limit = std.math.pi / 2.0;
