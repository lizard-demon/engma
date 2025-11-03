# Build System Guide

## Overview

Engma uses Zig's native build system with cross-platform compilation support. The build system handles native desktop builds and web (WASM) compilation through a unified configuration.

## Build Configuration Structure

### Main Build Script (`build.zig`)

```zig
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Dependency management
    const dep_sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize, .with_sokol_imgui = true });
    const dep_cimgui = b.dependency("cimgui", .{ .target = target, .optimize = optimize });
    const shdc = b.dependency("shdc", .{});
    
    // Shader compilation pipeline
    const shader = try @import("shdc").createSourceFile(b, .{
        .shdc_dep = shdc,
        .input = "src/engma/shader/cube/shader.glsl",
        .output = "src/engma/shader/cube/shader.glsl.zig",
        .slang = .{ .glsl410 = true, .glsl300es = true, .metal_macos = true, .wgsl = true },
    });
    
    // Target-specific build paths
    if (target.result.cpu.arch.isWasm()) {
        try buildWeb(b, main_module, shader, dep_sokol, dep_cimgui);
    } else {
        try buildNative(b, main_module, shader);
    }
}
```

### Dependency Management (`build.zig.zon`)

```zig
.{
    .name = "engma",
    .version = "0.1.0",
    .dependencies = .{
        .sokol = .{
            .url = "https://github.com/floooh/sokol-zig/archive/refs/heads/master.tar.gz",
            .hash = "...",
        },
        .cimgui = .{
            .url = "https://github.com/cimgui/cimgui/archive/refs/heads/docking_inter.tar.gz", 
            .hash = "...",
        },
        .shdc = .{
            .url = "https://github.com/floooh/sokol-tools-bin/archive/refs/heads/master.tar.gz",
            .hash = "...",
        },
    },
}
```

## Build Targets

### Native Desktop Build

```bash
# Build and run
zig build run

# Just build
zig build

# Release build
zig build -Doptimize=ReleaseFast
```

**Native Build Process**:
1. Compile shaders for desktop targets (GLSL 4.10, Metal)
2. Create executable with sokol-zig platform layer
3. Link with system graphics libraries (OpenGL/Metal/D3D11)
4. Generate optimized native code

### Web (WASM) Build

```bash
# Build for web
zig build web

# Or explicit WASM target
zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast
```

**Web Build Process**:
1. Compile shaders for web targets (GLSL 3.00 ES, WGSL)
2. Create WASM library with Emscripten
3. Generate HTML shell with WebGL context
4. Bundle with filesystem support

## Shader Compilation Pipeline

### Multi-Target Shader Compilation

The build system automatically compiles GLSL shaders to multiple target formats:

```zig
const shader = try @import("shdc").createSourceFile(b, .{
    .shdc_dep = shdc,
    .input = "src/engma/shader/cube/shader.glsl",
    .output = "src/engma/shader/cube/shader.glsl.zig",
    .slang = .{
        .glsl410 = true,      // Desktop OpenGL
        .glsl300es = true,    // WebGL
        .metal_macos = true,  // macOS Metal
        .wgsl = true,         // WebGPU
    },
});
```

### Generated Shader Interface

The shader compiler generates a Zig interface:

```zig
// Generated in shader.glsl.zig
pub fn desc(backend: sg.Backend) sg.ShaderDesc {
    return switch (backend) {
        .GLCORE33, .GLES3 => glsl410_desc(),
        .METAL_MACOS => metal_macos_desc(), 
        .WGPU => wgsl_desc(),
        else => @panic("Unsupported backend"),
    };
}
```

This enables compile-time shader selection based on the target platform.

## Module System

### Engine Module Structure

```zig
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
```

### Import Structure

```
main.zig
├── sokol (graphics/input/audio)
├── cimgui (immediate mode GUI)
└── engma
    ├── lib (core systems)
    ├── world (voxel implementations)
    ├── physics (movement systems)
    └── shader (rendering shaders)
```

## Platform-Specific Configuration

### Native Build Configuration

```zig
fn buildNative(b: *std.Build, main_module: *std.Build.Module, shader: *std.Build.Step) !void {
    const exe = b.addExecutable(.{
        .name = "fps",
        .root_module = main_module,
    });
    
    // Shader dependency
    exe.step.dependOn(shader);
    
    // Install and run steps
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    
    b.step("run", "Run the FPS engine").dependOn(&run.step);
}
```

### Web Build Configuration

```zig
fn buildWeb(b: *std.Build, main_module: *std.Build.Module, shader: *std.Build.Step, 
           dep_sokol: *std.Build.Dependency, dep_cimgui: *std.Build.Dependency) !void {
    
    const lib = b.addLibrary(.{
        .name = "fps",
        .root_module = main_module,
    });
    
    // Emscripten setup
    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    const emsdk_incl_path = emsdk.path("upstream/emscripten/cache/sysroot/include");
    
    // Link step with Emscripten
    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = lib,
        .target = main_module.resolved_target.?,
        .optimize = main_module.optimize.?,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = false,
        .use_filesystem = true,
        .shell_file_path = b.path("src/web/shell.html"),
        .extra_args = &.{ 
            "-sEXIT_RUNTIME=1", 
            "-sEXPORTED_RUNTIME_METHODS=['FS']", 
            "-sEXPORTED_FUNCTIONS=['_main']", 
            "-sFORCE_FILESYSTEM=1" 
        },
    });
}
```

## Build Optimization Levels

### Debug Build (`-Doptimize=Debug`)
- No optimizations
- Debug symbols included
- Runtime safety checks enabled
- Fast compilation

### Release Builds

#### ReleaseSafe (`-Doptimize=ReleaseSafe`)
- Optimizations enabled
- Runtime safety checks enabled
- Good for testing

#### ReleaseFast (`-Doptimize=ReleaseFast`)
- Maximum optimizations
- Runtime safety checks disabled
- Production builds

#### ReleaseSmall (`-Doptimize=ReleaseSmall`)
- Size optimizations
- Minimal binary size
- Good for web deployment

## Cross-Compilation Support

### Target Specification

```bash
# Windows from Linux/macOS
zig build -Dtarget=x86_64-windows

# macOS from Linux/Windows  
zig build -Dtarget=x86_64-macos

# Linux from Windows/macOS
zig build -Dtarget=x86_64-linux

# Web from any platform
zig build -Dtarget=wasm32-emscripten
```

### Architecture Support

```bash
# ARM64 (Apple Silicon, ARM servers)
zig build -Dtarget=aarch64-macos
zig build -Dtarget=aarch64-linux

# x86_64 (Intel/AMD)
zig build -Dtarget=x86_64-linux
zig build -Dtarget=x86_64-windows
```

## Development Workflow

### Incremental Development

```bash
# Fast iteration cycle
zig build run          # Build and run
# Make changes...
zig build run          # Incremental rebuild
```

### Shader Development

```bash
# Edit shader source
vim src/engma/shader/cube/shader.glsl

# Rebuild (shader recompilation automatic)
zig build run
```

### Web Development

```bash
# Build for web
zig build web

# Serve locally (requires local server)
cd zig-out/web
python -m http.server 8000
# Open http://localhost:8000
```

## Build System Benefits

### Unified Configuration
- Single build script for all platforms
- Consistent dependency management
- Automatic cross-compilation

### Fast Builds
- Incremental compilation
- Parallel builds
- Minimal dependencies

### Zero Configuration
- No external build tools required
- Self-contained build system
- Reproducible builds

### Cross-Platform
- Native builds for all major platforms
- Web deployment via WASM
- Consistent behavior across targets

This build system embodies the minimalist philosophy by providing maximum functionality with minimal configuration, enabling developers to focus on code rather than build complexity.