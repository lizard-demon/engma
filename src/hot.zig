// Hot-reloadable Meta-Engine - host gets sokol interface through plugin
const std = @import("std");

const libengine_path = "zig-out/lib/libengine.dylib";
var libengine: ?std.DynLib = null;

// Plugin function pointers (simplified interface)
var plug_pre_reload: *const fn () *anyopaque = undefined;
var plug_post_reload: *const fn (*anyopaque) void = undefined;

// Sokol interface provided by plugin
var plug_sapp_run: *const fn (?*anyopaque) void = undefined;

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

    plug_pre_reload = dyn_lib.lookup(@TypeOf(plug_pre_reload), "plug_pre_reload") orelse return false;
    plug_post_reload = dyn_lib.lookup(@TypeOf(plug_post_reload), "plug_post_reload") orelse return false;
    plug_sapp_run = dyn_lib.lookup(@TypeOf(plug_sapp_run), "plug_sapp_run") orelse return false;

    plugin_loaded = true;
    return true;
}

pub fn main() void {
    // Load the plugin first
    if (!reload_plugin()) {
        std.log.err("Failed to load engine plugin", .{});
        return;
    }

    // Let plugin run sokol - it handles everything internally now
    plug_sapp_run(null);
}
