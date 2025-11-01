const std = @import("std");
const sokol = @import("sokol");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const dep_sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize, .with_sokol_imgui = true });
    const dep_cimgui = b.dependency("cimgui", .{ .target = target, .optimize = optimize });
    const shdc = b.dependency("shdc", .{});

    // Bind ImGui to Sokol
    dep_sokol.artifact("sokol_clib").addIncludePath(dep_cimgui.path(@import("cimgui").getConfig(false).include_dir));

    // Shader compilation
    const shader = try @import("shdc").createSourceFile(b, .{
        .shdc_dep = shdc,
        .input = "src/engma/shader/cube/shader.glsl",
        .output = "src/engma/shader/cube/shader.glsl.zig",
        .slang = .{ .glsl410 = true, .glsl300es = true, .metal_macos = true, .wgsl = true },
    });

    // Engma module with proper dependency management
    const engma_module = b.createModule(.{
        .root_source_file = b.path("src/engma/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "cimgui", .module = dep_cimgui.module("cimgui") },
        },
    });

    // Main module with clean dependency structure
    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "cimgui", .module = dep_cimgui.module("cimgui") },
            .{ .name = "engma", .module = engma_module },
        },
    });

    // Build for WASM or native
    if (target.result.cpu.arch.isWasm()) {
        try buildWeb(b, .{
            .main_module = main_module,
            .dep_sokol = dep_sokol,
            .dep_cimgui = dep_cimgui,
            .shader = shader,
        });
    } else {
        try buildNative(b, .{
            .main_module = main_module,
            .shader = shader,
        });
    }

    // Convenience web build command
    const web = b.step("web", "Build for web (WASM)");
    const web_build = b.addSystemCommand(&.{ "zig", "build", "-Dtarget=wasm32-emscripten", "-Doptimize=ReleaseFast" });
    web.dependOn(&web_build.step);
}

const BuildOptions = struct {
    main_module: *std.Build.Module,
    shader: *std.Build.Step,
    dep_sokol: ?*std.Build.Dependency = null,
    dep_cimgui: ?*std.Build.Dependency = null,
};

fn buildNative(b: *std.Build, opts: BuildOptions) !void {
    const exe = b.addExecutable(.{
        .name = "fps",
        .root_module = opts.main_module,
    });
    exe.step.dependOn(opts.shader);

    // Modern artifact installation
    b.installArtifact(exe);

    // Run step with proper dependency management
    const run = b.addRunArtifact(exe);
    if (b.args) |args| {
        run.addArgs(args);
    }
    run.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the FPS engine");
    run_step.dependOn(&run.step);
}

fn buildWeb(b: *std.Build, opts: BuildOptions) !void {
    const lib = b.addLibrary(.{
        .name = "fps",
        .root_module = opts.main_module,
    });
    lib.step.dependOn(opts.shader);

    const emsdk = opts.dep_sokol.?.builder.dependency("emsdk", .{});
    const emsdk_incl_path = emsdk.path("upstream/emscripten/cache/sysroot/include");

    opts.dep_cimgui.?.artifact("cimgui_clib").addSystemIncludePath(emsdk_incl_path);
    opts.dep_cimgui.?.artifact("cimgui_clib").step.dependOn(&opts.dep_sokol.?.artifact("sokol_clib").step);

    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = lib,
        .target = opts.main_module.resolved_target.?,
        .optimize = opts.main_module.optimize.?,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = false,
        .use_filesystem = false,
        .shell_file_path = opts.dep_sokol.?.path("src/sokol/web/shell.html"),
        .extra_args = &.{"-sEXIT_RUNTIME=1"},
    });

    b.getInstallStep().dependOn(&link_step.step);

    const run = sokol.emRunStep(b, .{ .name = "fps", .emsdk = emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run the FPS engine").dependOn(&run.step);
}
