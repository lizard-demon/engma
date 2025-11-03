# Engma Documentation

Welcome to the comprehensive documentation for **Engma**, an ultra-minimalist meta-engine framework built in Zig.

## What is Engma?

Engma is a game engine that embodies the philosophy that **less is more**. It achieves maximum performance and flexibility through compile-time abstractions, zero-cost polymorphism, and data-oriented design principles.

## Documentation Structure

### 📋 [Architecture Overview](./architecture-overview.md)
Comprehensive overview of Engma's system architecture, module structure, and core design principles. Start here to understand how the engine works at a high level.

### 🎯 [Minimalist Design Philosophy](./minimalist-design-philosophy.md)
Deep dive into the ultra-minimalist philosophy that drives every design decision in Engma. Learn why constraints breed creativity and how "zero-cost abstractions" work in practice.

### 🔌 [System Interfaces Guide](./system-interfaces-guide.md)
Complete reference for the universal system interface and system-specific contracts. Essential reading for understanding how systems communicate and how to implement new ones.

### ⚡ [Performance Optimization Guide](./performance-optimization-guide.md)
Detailed guide to Engma's performance features including SIMD operations, data-oriented design, greedy meshing, and memory management strategies.

### 🔧 [Build System Guide](./build-system-guide.md)
Complete reference for Engma's build system, covering native and web builds, shader compilation, cross-platform support, and development workflows.

### 🚀 [Extending the Engine](./extending-the-engine.md)
Practical guide for adding new systems, creating custom world implementations, physics systems, shaders, and input handlers while maintaining the minimalist philosophy.

## Quick Start

```bash
# Clone and build
git clone <repository>
cd engma
zig build run

# Build for web
zig build web

# Release build
zig build -Doptimize=ReleaseFast
```

## Key Features

- **Zero-Cost Abstractions**: All polymorphism resolved at compile time
- **SIMD Operations**: Hardware-accelerated vector math
- **Cross-Platform**: Native desktop and web (WASM) from single codebase
- **Modular Design**: Swappable systems via compile-time configuration
- **Ultra-Minimal**: Maximum functionality with minimum complexity

## Architecture at a Glance

```zig
const Engine = struct {
    systems: struct {
        world: engma.world.greedy,                    // Voxel world with greedy meshing
        gfx: engma.lib.render(engma.shader.cube),    // Parameterized renderer
        body: engma.player.quake,                    // Quake-style movement
        keys: engma.lib.input,                       // Input abstraction
        audio: engma.lib.audio,                      // Audio system
        debug: engma.lib.debug,                      // Debug utilities
    },
};
```

All systems implement the same interface and are orchestrated via compile-time reflection:

```zig
engine.call("tick");  // Calls tick() on all systems
engine.call("draw");  // Calls draw() on all systems
```

## Performance Highlights

- **4096 voxels** stored in **512 bytes** (8:1 compression)
- **O(1) voxel access** via bitpacking
- **SIMD vector operations** for 3x performance boost
- **Greedy meshing** reduces face count by 10-100x
- **Zero allocations** in hot paths

## Philosophy in Practice

Every line of code in Engma serves a purpose. The engine achieves:

- **Compile-time everything**: No runtime overhead
- **Data-first design**: Cache-friendly, SIMD-optimized
- **Minimal dependencies**: Self-contained, reproducible builds
- **Cross-platform**: Single codebase, multiple targets

## Getting Help

1. **Start with [Architecture Overview](./architecture-overview.md)** for the big picture
2. **Read [System Interfaces Guide](./system-interfaces-guide.md)** to understand the contracts
3. **Check [Extending the Engine](./extending-the-engine.md)** for practical examples
4. **Consult [Performance Guide](./performance-optimization-guide.md)** for optimization techniques

## Contributing

When contributing to Engma, remember the core principles:

1. **Every line must have purpose** - no speculative features
2. **Zero-cost abstractions only** - no runtime overhead
3. **Compile-time over runtime** - resolve at build time
4. **Data-first design** - optimize for cache and SIMD

The goal is not just to build a game engine, but to prove that **minimalism and performance are not just compatible - they're synergistic**.

---

*"Perfection is achieved, not when there is nothing more to add, but when there is nothing left to take away."* - Antoine de Saint-Exupéry