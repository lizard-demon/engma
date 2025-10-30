// Hot-reloadable Meta-Engine - loads engine as dynamic library
const std = @import("std");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const simgui = sokol.imgui;

const libengine_path = "zig-out/lib/libengine.dylib";
var libengine: ?std.DynLib = null;

// Plugin function pointers (standard Zig plugin interface)
var plug_init: *const fn () void = undefined;
var plug_deinit: *const fn () void = undefined;
var plug_pre_reload: *const fn () *anyopaque = undefined;
var plug_post_reload: *const fn (*anyopaque) void = undefined;
var plug_update: *const fn () void = undefined;
var plug_event: *const fn (sokol.app.Event) void = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var plugin_loaded: bool = false;

fn reload_plugin() bool {
    if (libengine) |*lib| {
        lib.close();
        libengine = null;
        plugin_loaded = false;
    }

    var dyn_lib = std.DynLib.open(libengine_path) catch {
        std.log.err("Failed to open plugin: {s}", .{libengine_path});
        return false;
    };

    libengine = dyn_lib;

    plug_init = dyn_lib.lookup(@TypeOf(plug_init), "plug_init") orelse return false;
    plug_deinit = dyn_lib.lookup(@TypeOf(plug_deinit), "plug_deinit") orelse return false;
    plug_pre_reload = dyn_lib.lookup(@TypeOf(plug_pre_reload), "plug_pre_reload") orelse return false;
    plug_post_reload = dyn_lib.lookup(@TypeOf(plug_post_reload), "plug_post_reload") orelse return false;
    plug_update = dyn_lib.lookup(@TypeOf(plug_update), "plug_update") orelse return false;
    plug_event = dyn_lib.lookup(@TypeOf(plug_event), "plug_event") orelse return false;

    plugin_loaded = true;
    return true;
}

export fn init() void {
    // Initialize graphics context once in host
    sg.setup(.{ .environment = sokol.glue.environment() });
    simgui.setup(.{});

    // Load the hot-reloadable plugin
    if (!reload_plugin()) {
        std.log.err("Failed to load engine plugin", .{});
        return;
    }

    plug_init();
    std.log.info("Hot-reloadable engine initialized! Press R to reload", .{});
}

export fn frame() void {
    if (plugin_loaded) {
        plug_update();
    }
}

export fn cleanup() void {
    if (plugin_loaded) {
        plug_deinit();
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
        std.log.info("Reloading plugin...", .{});
        if (plugin_loaded) {
            const state = plug_pre_reload();
            if (reload_plugin()) {
                plug_init();
                plug_post_reload(state);
                std.log.info("Plugin reloaded successfully!", .{});
            } else {
                std.log.err("Plugin reload failed!", .{});
            }
        }
        return;
    }

    // Pass event to plugin
    if (plugin_loaded) {
        plug_event(ev);
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
