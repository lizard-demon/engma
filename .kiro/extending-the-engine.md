# Extending the Engine Guide

## Core Extension Principles

Engma's ultra-minimalist design enables extension through **compile-time composition** rather than runtime configuration. Extensions are achieved by implementing standard interfaces and leveraging Zig's powerful compile-time system.

## Adding New Systems

### 1. Implement the Universal Interface

All systems must implement the five-method interface:

```zig
pub const MySystem = struct {
    // System state
    state: f32,
    
    pub fn init(self: *MySystem, engine: anytype) void {
        self.* = .{ .state = 0.0 };
    }
    
    pub fn tick(self: *MySystem, engine: anytype) void {
        // Update logic
        self.state += engine.dt;
    }
    
    pub fn draw(self: *MySystem, engine: anytype) void {
        // Rendering logic
    }
    
    pub fn event(self: *MySystem, engine: anytype) void {
        // Event handling
        const e = engine.event;
        // Process events...
    }
    
    pub fn deinit(self: *MySystem, engine: anytype) void {
        // Cleanup
    }
};
```

### 2. Add to Engine Configuration

```zig
const Engine = struct {
    systems: struct {
        world: engma.world.greedy,
        gfx: engma.lib.render(engma.shader.cube),
        body: engma.player.quake,
        keys: engma.lib.input,
        audio: engma.lib.audio,
        debug: engma.lib.debug,
        my_system: MySystem,  // Add new system here
    },
};
```

The engine will automatically call all interface methods on your system via compile-time reflection.

## Creating New World Systems

### World Interface Requirements

```zig
pub const MyWorld = struct {
    // World data
    voxels: [SIZE][SIZE][SIZE]bool,
    
    // Required interface methods
    pub fn init(self: *MyWorld, engine: anytype) void { /* ... */ }
    pub fn tick(self: *MyWorld, engine: anytype) void { /* ... */ }
    pub fn draw(self: *MyWorld, engine: anytype) void { /* ... */ }
    pub fn event(self: *MyWorld, engine: anytype) void { /* ... */ }
    pub fn deinit(self: *MyWorld, engine: anytype) void { /* ... */ }
    
    // World-specific interface
    pub fn get(self: *const MyWorld, x: i32, y: i32, z: i32) bool {
        if (x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE) 
            return false;
        return self.voxels[@intCast(x)][@intCast(y)][@intCast(z)];
    }
    
    pub fn mesh(self: *const MyWorld, vertices: []math.Vertex, indices: []u16) math.Mesh {
        // Generate mesh from voxel data
        var vi: usize = 0;
        var ii: usize = 0;
        
        // Mesh generation algorithm...
        
        return .{ .vertices = vertices[0..vi], .indices = indices[0..ii] };
    }
};
```

### Advanced World Features

#### Procedural Generation
```zig
pub fn init(self: *MyWorld, engine: anytype) void {
    // Generate world procedurally
    for (0..SIZE) |x| for (0..SIZE) |y| for (0..SIZE) |z| {
        const noise_value = perlinNoise(@floatFromInt(x), @floatFromInt(y), @floatFromInt(z));
        self.voxels[x][y][z] = noise_value > 0.5;
    };
}
```

#### Dynamic Modification
```zig
pub fn setVoxel(self: *MyWorld, x: i32, y: i32, z: i32, value: bool) void {
    if (x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE) return;
    self.voxels[@intCast(x)][@intCast(y)][@intCast(z)] = value;
    
    // Invalidate mesh cache to trigger regeneration
    self.mesh_dirty = true;
}
```

## Creating New Physics Systems

### Physics Interface Requirements

```zig
pub const MyPhysics = struct {
    position: math.Vec3,
    velocity: math.Vec3,
    orientation: math.Mat4,
    
    // Required interface methods
    pub fn init(self: *MyPhysics, engine: anytype) void { /* ... */ }
    pub fn tick(self: *MyPhysics, engine: anytype) void { /* ... */ }
    pub fn draw(self: *MyPhysics, engine: anytype) void { /* ... */ }
    pub fn event(self: *MyPhysics, engine: anytype) void { /* ... */ }
    pub fn deinit(self: *MyPhysics, engine: anytype) void { /* ... */ }
    
    // Physics-specific interface
    pub fn view(self: *const MyPhysics) math.Mat4 {
        // Return camera view matrix
        return self.orientation;
    }
    
    pub fn mouse(self: *MyPhysics, dx: f32, dy: f32) void {
        // Handle mouse input for camera control
        // Update orientation based on mouse delta
    }
};
```

### Physics System Examples

#### Orbital Camera
```zig
pub const OrbitalPhysics = struct {
    distance: f32,
    azimuth: f32,
    elevation: f32,
    target: math.Vec3,
    
    pub fn tick(self: *OrbitalPhysics, engine: anytype) void {
        // Orbital camera movement
        if (engine.systems.keys.forward()) self.distance -= 5.0 * engine.dt;
        if (engine.systems.keys.back()) self.distance += 5.0 * engine.dt;
        
        self.distance = std.math.clamp(self.distance, 1.0, 50.0);
    }
    
    pub fn view(self: *const OrbitalPhysics) math.Mat4 {
        const x = self.distance * @cos(self.elevation) * @cos(self.azimuth);
        const y = self.distance * @sin(self.elevation);
        const z = self.distance * @cos(self.elevation) * @sin(self.azimuth);
        
        const eye = math.Vec3.add(self.target, math.Vec3.new(x, y, z));
        return lookAt(eye, self.target, math.Vec3.new(0, 1, 0));
    }
};
```

#### Flying Physics
```zig
pub const FlyingPhysics = struct {
    pos: math.Vec3,
    vel: math.Vec3,
    yaw: f32,
    pitch: f32,
    
    pub fn tick(self: *FlyingPhysics, engine: anytype) void {
        // 6DOF movement
        var dir = math.Vec3.zero();
        
        if (engine.systems.keys.forward()) dir = math.Vec3.add(dir, self.forward());
        if (engine.systems.keys.back()) dir = math.Vec3.sub(dir, self.forward());
        if (engine.systems.keys.left()) dir = math.Vec3.sub(dir, self.right());
        if (engine.systems.keys.right()) dir = math.Vec3.add(dir, self.right());
        if (engine.systems.keys.jump()) dir = math.Vec3.add(dir, math.Vec3.new(0, 1, 0));
        if (engine.systems.keys.crouch()) dir = math.Vec3.sub(dir, math.Vec3.new(0, 1, 0));
        
        const speed = 10.0;
        self.vel = math.Vec3.scale(dir, speed);
        self.pos = math.Vec3.add(self.pos, math.Vec3.scale(self.vel, engine.dt));
    }
    
    fn forward(self: *const FlyingPhysics) math.Vec3 {
        return math.Vec3.new(@sin(self.yaw) * @cos(self.pitch), -@sin(self.pitch), -@cos(self.yaw) * @cos(self.pitch));
    }
    
    fn right(self: *const FlyingPhysics) math.Vec3 {
        return math.Vec3.new(@cos(self.yaw), 0, @sin(self.yaw));
    }
};
```

## Creating New Shaders

### Shader Module Structure

```
src/engma/shader/my_shader/
├── mod.zig              # Shader interface
├── shader.glsl          # GLSL source
└── shader.glsl.zig      # Generated (by build system)
```

### Shader Interface (`mod.zig`)

```zig
const sg = @import("sokol").gfx;

// Import generated shader descriptors
const shd = @import("shader.glsl.zig");

pub fn desc(backend: sg.Backend) sg.ShaderDesc {
    return shd.desc(backend);
}

// Optional: shader-specific uniforms
pub const Uniforms = struct {
    mvp: [16]f32,
    time: f32,
    color: [4]f32,
};
```

### GLSL Shader Source (`shader.glsl`)

```glsl
@ctype mat4 Mat4
@ctype vec4 Vec4

@vs vs
uniform vs_params {
    Mat4 mvp;
    float time;
    Vec4 color;
};

in vec4 position;
in vec4 color0;

out vec4 color;

void main() {
    gl_Position = mvp * position;
    color = color0 * color * (0.5 + 0.5 * sin(time));
}
@end

@fs fs
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = color;
}
@end

@program my_shader vs fs
```

### Using Custom Shaders

```zig
const Engine = struct {
    systems: struct {
        // Use custom shader with renderer
        gfx: engma.lib.render(engma.shader.my_shader),
        // ... other systems
    },
};
```

## Adding New Input Systems

### Custom Input Interface

```zig
pub const GamepadInput = struct {
    gamepad_state: GamepadState,
    
    // Required interface methods
    pub fn init(self: *GamepadInput, engine: anytype) void { /* ... */ }
    pub fn tick(self: *GamepadInput, engine: anytype) void { /* ... */ }
    pub fn draw(self: *GamepadInput, engine: anytype) void { /* ... */ }
    pub fn event(self: *GamepadInput, engine: anytype) void { /* ... */ }
    pub fn deinit(self: *GamepadInput, engine: anytype) void { /* ... */ }
    
    // Input-specific interface
    pub fn forward(self: *const GamepadInput) bool {
        return self.gamepad_state.left_stick_y > 0.5;
    }
    
    pub fn back(self: *const GamepadInput) bool {
        return self.gamepad_state.left_stick_y < -0.5;
    }
    
    pub fn left(self: *const GamepadInput) bool {
        return self.gamepad_state.left_stick_x < -0.5;
    }
    
    pub fn right(self: *const GamepadInput) bool {
        return self.gamepad_state.left_stick_x > 0.5;
    }
    
    pub fn jump(self: *const GamepadInput) bool {
        return self.gamepad_state.button_a;
    }
    
    pub fn crouch(self: *const GamepadInput) bool {
        return self.gamepad_state.button_b;
    }
};
```

## Compile-Time System Selection

### Conditional Compilation

```zig
const BUILD_CONFIG = struct {
    const WORLD_TYPE = .greedy;  // .greedy, .voxel, .procedural
    const PHYSICS_TYPE = .quake; // .quake, .flying, .orbital
    const RENDERER_TYPE = .cube; // .cube, .pbr, .toon
};

const Engine = struct {
    systems: struct {
        world: switch (BUILD_CONFIG.WORLD_TYPE) {
            .greedy => engma.world.greedy,
            .voxel => engma.world.voxel,
            .procedural => engma.world.procedural,
        },
        
        body: switch (BUILD_CONFIG.PHYSICS_TYPE) {
            .quake => engma.player.quake,
            .flying => engma.physics.flying,
            .orbital => engma.physics.orbital,
        },
        
        gfx: switch (BUILD_CONFIG.RENDERER_TYPE) {
            .cube => engma.lib.render(engma.shader.cube),
            .pbr => engma.lib.render(engma.shader.pbr),
            .toon => engma.lib.render(engma.shader.toon),
        },
        
        keys: engma.lib.input,
        audio: engma.lib.audio,
        debug: engma.lib.debug,
    },
};
```

### Feature Flags

```zig
const FEATURES = struct {
    const ENABLE_AUDIO = true;
    const ENABLE_DEBUG = @import("builtin").mode == .Debug;
    const ENABLE_NETWORKING = false;
};

const Engine = struct {
    systems: struct {
        world: engma.world.greedy,
        gfx: engma.lib.render(engma.shader.cube),
        body: engma.player.quake,
        keys: engma.lib.input,
        
        // Conditional systems
        audio: if (FEATURES.ENABLE_AUDIO) engma.lib.audio else void,
        debug: if (FEATURES.ENABLE_DEBUG) engma.lib.debug else void,
        network: if (FEATURES.ENABLE_NETWORKING) engma.lib.network else void,
    },
};
```

## Extension Best Practices

### 1. Follow the Interface Contract
- Always implement all five interface methods
- Use `anytype` for engine parameter to maintain flexibility
- Handle edge cases gracefully

### 2. Minimize State
- Keep system state minimal and focused
- Avoid redundant data storage
- Use compile-time constants where possible

### 3. Optimize for Performance
- Use SIMD operations for math
- Minimize allocations in hot paths
- Leverage compile-time optimizations

### 4. Maintain Composability
- Systems should be independent and swappable
- Avoid tight coupling between systems
- Use the engine state for communication

### 5. Document Interfaces
- Clearly document system-specific methods
- Provide usage examples
- Explain performance characteristics

This extension system maintains Engma's minimalist philosophy while providing maximum flexibility through compile-time composition and zero-cost abstractions.