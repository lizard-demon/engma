const std = @import("std");
const sokol = @import("sokol");

pub const Keys = struct {
    bits: packed struct { w: bool = false, a: bool = false, s: bool = false, d: bool = false, space: bool = false, ctrl: bool = false },
    locked: bool = false,

    pub fn init(_: std.mem.Allocator) Keys {
        return .{ .bits = .{}, .locked = false };
    }

    pub fn deinit(_: *Keys, _: std.mem.Allocator) void {}
    pub fn tick(_: *Keys, _: f32) void {}

    pub fn event(self: *Keys, e: sokol.app.Event) void {
        const down = e.type == .KEY_DOWN;
        switch (e.type) {
            .KEY_DOWN, .KEY_UP => switch (e.key_code) {
                .W => self.bits.w = down,
                .A => self.bits.a = down,
                .S => self.bits.s = down,
                .D => self.bits.d = down,
                .SPACE => self.bits.space = down,
                .LEFT_CONTROL => self.bits.ctrl = down,
                .ESCAPE => if (down and self.locked) {
                    self.locked = false;
                    sokol.app.showMouse(true);
                    sokol.app.lockMouse(false);
                },
                else => {},
            },
            .MOUSE_DOWN => if (e.mouse_button == .LEFT and !self.locked) {
                self.locked = true;
                sokol.app.showMouse(false);
                sokol.app.lockMouse(true);
            },
            else => {},
        }
    }

    pub fn forward(self: *const Keys) bool {
        return self.bits.w;
    }
    pub fn back(self: *const Keys) bool {
        return self.bits.s;
    }
    pub fn left(self: *const Keys) bool {
        return self.bits.a;
    }
    pub fn right(self: *const Keys) bool {
        return self.bits.d;
    }
    pub fn jump(self: *const Keys) bool {
        return self.bits.space;
    }
    pub fn crouch(self: *const Keys) bool {
        return self.bits.ctrl;
    }
};
