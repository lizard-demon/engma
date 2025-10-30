// Hot-reloading meta-engine - simple file watching with process restart
const std = @import("std");
const engine = @import("engine");

const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const simgui = sokol.imgui;

// Use greedy meshed world configuration
const Config = struct {
    pub const World = engine.world.greedy;
    pub const Gfx = engine.lib.render(engine.shader.cube);
    pub const Body = engine.physics.quake;
    pub const Keys = engine.lib.input;
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var game_engine: engine.Engine(Config) = undefined;
var file_watcher: ?std.Thread = null;
var should_exit = std.atomic.Value(bool).init(false);

// Simple file watcher that triggers rebuild and restart
fn watchFiles() void {
    const watch_files = [_][]const u8{
        "src/engine/world/greedy.zig",
        "src/engine/physics/quake.zig",
        "src/engine/lib/math.zig",
    };

    var file_times: [watch_files.len]i64 = undefined;

    // Initialize file times
    for (watch_files, 0..) |file_path, i| {
        file_times[i] = getFileModTime(file_path) orelse 0;
    }

    while (!should_exit.load(.monotonic)) {
        std.Thread.sleep(500 * std.time.ns_per_ms);

        for (watch_files, 0..) |file_path, i| {
            if (getFileModTime(file_path)) |mod_time| {
                if (mod_time > file_times[i]) {
                    std.log.info("File changed: {s} - triggering rebuild", .{file_path});
                    file_times[i] = mod_time;

                    // Wait a bit for file writes to complete
                    std.Thread.sleep(100 * std.time.ns_per_ms);

                    if (rebuildAndRestart()) {
                        return; // Exit watcher thread
                    }
                }
            }
        }
    }
}

fn getFileModTime(path: []const u8) ?i64 {
    const file = std.fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();

    const stat = file.stat() catch return null;
    return @intCast(stat.mtime);
}

fn rebuildAndRestart() bool {
    std.log.info("Rebuilding...", .{});

    // Build the project
    var child = std.process.Child.init(&[_][]const u8{ "zig", "build", "hot" }, gpa.allocator());
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Pipe;

    child.spawn() catch {
        std.log.err("Failed to spawn rebuild", .{});
        return false;
    };

    const result = child.wait() catch {
        std.log.err("Failed to wait for rebuild", .{});
        return false;
    };

    switch (result) {
        .Exited => |code| {
            if (code == 0) {
                std.log.info("Rebuild successful - restarting...", .{});

                // Signal the main thread to exit
                should_exit.store(true, .release);
                sapp.requestQuit();

                // Spawn new process
                var restart_child = std.process.Child.init(&[_][]const u8{"./zig-out/bin/fps_hot"}, gpa.allocator());
                restart_child.spawn() catch {
                    std.log.err("Failed to restart process", .{});
                    return false;
                };

                return true;
            } else {
                std.log.err("Rebuild failed with code: {}", .{code});
                return false;
            }
        },
        else => {
            std.log.err("Rebuild process terminated unexpectedly", .{});
            return false;
        },
    }
}

export fn init() void {
    // Initialize graphics context
    sg.setup(.{ .environment = sokol.glue.environment() });
    simgui.setup(.{});

    // Initialize engine
    game_engine = engine.Engine(Config).init();

    // Start file watcher thread
    file_watcher = std.Thread.spawn(.{}, watchFiles, .{}) catch |err| {
        std.log.err("Failed to start file watcher: {}", .{err});
        return;
    };

    std.log.info("Hot-reloading engine started! Edit watched files to trigger rebuild.", .{});
}

export fn frame() void {
    // Check if we should exit
    if (should_exit.load(.monotonic)) {
        sapp.requestQuit();
        return;
    }

    game_engine.tick();
    game_engine.draw();
}

export fn cleanup() void {
    should_exit.store(true, .monotonic);

    if (file_watcher) |thread| {
        thread.join();
    }

    game_engine.deinit();
    simgui.shutdown();
    sg.shutdown();
    _ = gpa.deinit();
}

export fn event(e: [*c]const sokol.app.Event) void {
    game_engine.event(e.*);
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = 800,
        .height = 600,
        .window_title = "Hot-Reloading Meta-Engine",
    });
}
