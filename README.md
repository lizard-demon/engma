# Meta-Engine

A brutalist, hyper-minimalist, swappable meta-engine built in Zig. Pure abstraction over implementations. Inspired by the architectural genius of the FPS demo.

## Philosophy

Ultra-minimal SLOC. Professional module system with clean separation of concerns. Engine is a proper build module with standard `mod.zig` entry point. Clean relative imports within the engine module. Worlds generate meshes, renderers render them. Swap implementations like changing socks. Direct access to meta-modules without redundant type names. Pure abstraction over concrete implementations. No bloat, no bullshit, just raw meta-engine power.

## Architecture

```
src/
├── main.zig          # Configuration and entry point
└── engine/           # Professional engine module (self-contained)
    ├── mod.zig           # Engine module entry point + namespace system
    ├── lib/
    │   ├── math.zig      # Vector/matrix primitives
    │   └── input.zig     # Input handling (core utility)
    ├── world/
    │   └── voxel.zig     # Bitpacked voxel world (swappable)
    ├── render/
    │   └── sokol.zig     # Sokol renderer with mesh generation (swappable)
    ├── physics/
    │   └── simple.zig    # Simple physics - velocity, forces, dynamics (swappable)
    └── shader/
        └── cube/         # Cube shader module (professional shader interface)
            ├── mod.zig       # Clean shader interface
            ├── shader.glsl   # GLSL shader source
            └── shader.glsl.zig # Generated shader code
```

## Swapping Implementations

Want a different renderer? Physics system? World format? Just swap the namespaced imports in `main.zig`:

```zig
const engine = @import("engine.zig");

// Professional namespace aliases
const world = engine.world;
const phys = engine.physics;
const gfx = engine.render;
const lib = engine.lib;
const shaders = engine.shader;

const Config = struct {
    pub const World = world.height;     // ← Swap this
    pub const Gfx = gfx.vulkan(shaders.pbr);  // ← Swap renderer + shader  
    pub const Body = phys.verlet;       // ← Or this
    pub const Keys = lib.input;         // ← Core utility (rarely swapped)
};
```

## Running

```bash
zig build run
```

## Controls

- **WASD**: Move
- **Mouse**: Look around  
- **Space**: Jump
- **Click**: Capture mouse
- **Escape**: Release mouse

## Algorithmic Art

Each module is distilled to its pure mathematical essence:

**World** (35 lines):
- 4096 voxels bitpacked into 512 bytes
- Bit manipulation: `bits[i >> 3] |= 1 << (i & 7)`
- Face-culled mesh generation with color coding
- Direct voxel queries via coordinate indexing

**Player** (40 lines):
- Physics dynamics: velocity, forces, gravity, movement
- Namespace organization: `Player.Update.movement()`, `Player.Update.physics()`
- View matrix: camera positioning with eye offset
- Collision response: integrates with world spatial queries

**Input** (15 lines):
- Packed bit struct for key states
- Event state machine with mouse lock toggle
- Zero overhead boolean accessors

**Gfx** (20 lines):
- Generic mesh rendering pipeline
- World-agnostic vertex buffer management
- Direct GPU resource creation from world-generated meshes



The core meta-engine is completely generic - pure dependency injection through Zig's compile-time generics with professional meta-namespace access. True abstraction over concrete implementations following brutalist `Struct.func()` naming.

## Adding New Implementations

Each module follows the brutalist `Struct.func()` naming scheme with capital structs, short function names, and organized namespaces like `Player.Update.movement()`:

```zig
// World interface
World.init() -> World
World.get(x, y, z) -> bool
World.mesh(vertices, indices) -> Mesh

// Gfx interface  
Gfx.init() -> Gfx
Gfx.draw(world, view) -> void
Gfx.dt() -> f32
Gfx.deinit() -> void

// Player interface
Player.init() -> Player
Player.tick(world, keys, dt) -> void
Player.view() -> Mat
Player.mouse(dx, dy) -> void
Player.Update.movement(player, dir, dt) -> void
Player.Update.physics(player, world, dt) -> void

// Keys interface
Keys.init() -> Keys
Keys.tick() -> void
Keys.event(e) -> void
Keys.forward/back/left/right/jump() -> bool
```

That's it. No inheritance, no virtual dispatch, no runtime overhead. Just compile-time composition.

## Why This Rocks

- **Minimal**: Each module is <40 lines of pure algorithm
- **Fast**: SIMD vectors, bitpacking, zero runtime overhead
- **Mathematical**: Every line serves the core algorithm
- **Swappable**: Change world/physics/renderer without touching others
- **Artistic**: Code as algorithmic poetry

This is computational minimalism. Every bit serves a purpose. Every line is essential. Pure algorithmic beauty.