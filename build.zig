const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize, .with_sokol_imgui = true });
    const cimgui = b.dependency("cimgui", .{ .target = target, .optimize = optimize });
    const shdc = b.dependency("shdc", .{});

    // Bind ImGui to Sokol
    sokol.artifact("sokol_clib").addIncludePath(cimgui.path(@import("cimgui").getConfig(false).include_dir));

    // Shader compilation
    const shader = try @import("shdc").createSourceFile(b, .{
        .shdc_dep = shdc,
        .input = "src/engine/shader/cube/shader.glsl",
        .output = "src/engine/shader/cube/shader.glsl.zig",
        .slang = .{ .glsl410 = true, .glsl300es = true, .metal_macos = true, .wgsl = true },
    });

    // Engine module
    const engine_module = b.createModule(.{
        .root_source_file = b.path("src/engine/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_module.addImport("sokol", sokol.module("sokol"));
    engine_module.addImport("cimgui", cimgui.module("cimgui"));

    // Executable
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

    // Run command
    const run = b.step("run", "Run the FPS engine");
    run.dependOn(&b.addRunArtifact(exe).step);
}
