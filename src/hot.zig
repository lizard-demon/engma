// Hot-reloadable Meta-Engine - loads engine as dynamic library
const std = @import("std");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const simgui = sokol.imgui;

const libengine_path = "zig-out/lib/libengine.dylib";
var libengine: ?std.DynLib = null;

// Engine function pointers
var engine_init: *const fn () void = undefined;
var engine_destroy: *const fn () void = undefined;
var engine_pre_reload: *const fn () *anyopaque = undefined;
var engine_post_reload: *const fn (*anyopaque) void = undefined;
var engine_tick: *const fn () void = undefined;
var engine_draw: *const fn () void = undefined;
var engine_event: *const fn (sokol.app.Event) void = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var engine_loaded: bool = false;

fn reload_engine() bool {
    if (libengine) |*lib| {
        lib.close();
        libengine = null;
        engine_loaded = false;
    }

    var dyn_lib = std.DynLib.open(libengine_path) catch {
        std.log.err("Failed to open engine: {s}", .{libengine_path});
        return false;
    };

    libengine = dyn_lib;

    engine_init = dyn_lib.lookup(@TypeOf(engine_init), "engine_init") orelse return false;
    engine_destroy = dyn_lib.lookup(@TypeOf(engine_destroy), "engine_destroy") orelse return false;
    engine_pre_reload = dyn_lib.lookup(@TypeOf(engine_pre_reload), "engine_pre_reload") orelse return false;
    engine_post_reload = dyn_lib.lookup(@TypeOf(engine_post_reload), "engine_post_reload") orelse return false;
    engine_tick = dyn_lib.lookup(@TypeOf(engine_tick), "engine_tick") orelse return false;
    engine_draw = dyn_lib.lookup(@TypeOf(engine_draw), "engine_draw") orelse return false;
    engine_event = dyn_lib.lookup(@TypeOf(engine_event), "engine_event") orelse return false;

    engine_loaded = true;
    return true;
}

export fn init() void {
    // Initialize graphics context once in host
    sg.setup(.{ .environment = sokol.glue.environment() });
    simgui.setup(.{});

    // Load the hot-reloadable engine
    if (!reload_engine()) {
        std.log.err("Failed to load engine plugin", .{});
        return;
    }

    engine_init();
    std.log.info("Hot-reloadable engine initialized! Press R to reload", .{});
}

export fn frame() void {
    if (engine_loaded) {
        engine_tick();
        engine_draw();
    }
}

export fn cleanup() void {
    if (engine_loaded) {
        engine_destroy();
    }

    if (libengine) |*lib| {
        lib.close();
    }

    simgui.shutdown();
    sg.shutdown();
    _ = gpa.deinit();
}

export fn event(e: [*c]const sokol.app.Event) void {
    const ev = e.*;

    // Hot reload on R key
    if (ev.type == .KEY_DOWN and ev.key_code == .R) {
        std.log.info("Reloading engine...", .{});
        if (engine_loaded) {
            const state = engine_pre_reload();
            if (reload_engine()) {
                engine_init();
                engine_post_reload(state);
                std.log.info("Engine reloaded successfully!", .{});
            } else {
                std.log.err("Engine reload failed!", .{});
            }
        }
        return;
    }

    // Pass event to engine
    if (engine_loaded) {
        engine_event(ev);
    }
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = 800,
        .height = 600,
        .window_title = "Hot-Reloadable Meta-Engine (Press R to reload)",
    });
}
