const std = @import("std");
const sokol = @import("sokol");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize, .with_sokol_imgui = true });
    const dep_cimgui = b.dependency("cimgui", .{ .target = target, .optimize = optimize });
    const shdc = b.dependency("shdc", .{});

    dep_sokol.artifact("sokol_clib").addIncludePath(dep_cimgui.path(@import("cimgui").getConfig(false).include_dir));

    const shader = try @import("shdc").createSourceFile(b, .{
        .shdc_dep = shdc,
        .input = "src/engma/shader/cube/shader.glsl",
        .output = "src/engma/shader/cube/shader.glsl.zig",
        .slang = .{ .glsl410 = true, .glsl300es = true, .metal_macos = true, .wgsl = true },
    });

    const engma_module = b.createModule(.{
        .root_source_file = b.path("src/engma/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "cimgui", .module = dep_cimgui.module("cimgui") },
        },
    });

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

    if (target.result.cpu.arch.isWasm()) {
        try buildWeb(b, main_module, shader, dep_sokol, dep_cimgui);
    } else {
        try buildNative(b, main_module, shader);
    }

    const web = b.step("web", "Build for web (WASM)");
    const web_build = b.addSystemCommand(&.{ "zig", "build", "-Dtarget=wasm32-emscripten", "-Doptimize=ReleaseFast" });
    web.dependOn(&web_build.step);
}

fn buildNative(b: *std.Build, main_module: *std.Build.Module, shader: *std.Build.Step) !void {
    const exe = b.addExecutable(.{
        .name = "fps",
        .root_module = main_module,
    });
    exe.step.dependOn(shader);
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    run.step.dependOn(b.getInstallStep());

    b.step("run", "Run the FPS engine").dependOn(&run.step);
}

fn buildWeb(b: *std.Build, main_module: *std.Build.Module, shader: *std.Build.Step, dep_sokol: *std.Build.Dependency, dep_cimgui: *std.Build.Dependency) !void {
    const lib = b.addLibrary(.{
        .name = "fps",
        .root_module = main_module,
    });
    lib.step.dependOn(shader);

    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    const emsdk_incl_path = emsdk.path("upstream/emscripten/cache/sysroot/include");

    const cimgui_conf = @import("cimgui").getConfig(false);
    dep_cimgui.artifact(cimgui_conf.clib_name).addSystemIncludePath(emsdk_incl_path);
    dep_cimgui.artifact(cimgui_conf.clib_name).step.dependOn(&dep_sokol.artifact("sokol_clib").step);

    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = lib,
        .target = main_module.resolved_target.?,
        .optimize = main_module.optimize.?,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = false,
        .use_filesystem = true,
        .shell_file_path = b.path("src/web/shell.html"),
        .extra_args = &.{ "-sEXIT_RUNTIME=1", "-sEXPORTED_RUNTIME_METHODS=['FS']", "-sEXPORTED_FUNCTIONS=['_main']", "-sFORCE_FILESYSTEM=1" },
    });

    b.getInstallStep().dependOn(&link_step.step);

    const run = sokol.emRunStep(b, .{ .name = "fps", .emsdk = emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run the FPS engine").dependOn(&run.step);
}
