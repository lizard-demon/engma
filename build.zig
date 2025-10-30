const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target, const optimize = .{ b.standardTargetOptions(.{}), b.standardOptimizeOption(.{}) };

    // Dependencies
    const sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize, .with_sokol_imgui = true });
    const cimgui = b.dependency("cimgui", .{ .target = target, .optimize = optimize });
    const shdc = b.dependency("shdc", .{});

    // Bind ImGui to Sokol
    sokol.artifact("sokol_clib").addIncludePath(cimgui.path(@import("cimgui").getConfig(false).include_dir));

    // Shader compilation
    const shader = try @import("shdc").createSourceFile(b, .{ .shdc_dep = shdc, .input = "src/engine/shader/cube/shader.glsl", .output = "src/engine/shader/cube/shader.glsl.zig", .slang = .{ .glsl410 = true, .glsl300es = true, .metal_macos = true, .wgsl = true } });

    // Create engine module as a proper separate module
    const engine_module = b.createModule(.{
        .root_source_file = b.path("src/engine/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Engine module needs sokol for render modules
    engine_module.addImport("sokol", sokol.module("sokol"));
    engine_module.addImport("cimgui", cimgui.module("cimgui"));

    // Regular executable
    const exe = b.addExecutable(.{
        .name = "fps",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addImport("sokol", sokol.module("sokol"));
    exe.root_module.addImport("cimgui", cimgui.module("cimgui"));
    exe.root_module.addImport("engine", engine_module);
    exe.step.dependOn(shader);

    b.installArtifact(exe);

    // Engine dynamic library for hot swapping
    const engine_lib = b.addLibrary(.{
        .name = "engine",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/engine/plug.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    engine_lib.root_module.addImport("sokol", sokol.module("sokol"));
    engine_lib.root_module.addImport("cimgui", cimgui.module("cimgui"));
    engine_lib.root_module.addImport("engine", engine_module);
    engine_lib.step.dependOn(shader);
    b.installArtifact(engine_lib);

    // Hot-swappable executable
    const hot_exe = b.addExecutable(.{
        .name = "fps_hot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/hot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Hot executable only needs basic functionality - no graphics dependencies

    b.installArtifact(hot_exe);

    // Run commands
    const run = b.step("run", "Launch the ultraminimal FPS experience");
    run.dependOn(&b.addRunArtifact(exe).step);

    const run_hot = b.step("hot", "Launch the hot-reloadable meta-engine");
    run_hot.dependOn(&b.addRunArtifact(hot_exe).step);
    run_hot.dependOn(&engine_lib.step);

    const build_engine = b.step("engine", "Build engine dynamic library");
    build_engine.dependOn(&engine_lib.step);
}
