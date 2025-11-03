# System Interfaces Guide

## Universal System Interface

All systems in Engma implement the same five-method interface, enabling uniform orchestration via compile-time reflection.

### Core Interface Contract

```zig
pub fn init(self: *System, engine: Engine) void
pub fn tick(self: *System, engine: Engine) void  
pub fn draw(self: *System, engine: Engine) void
pub fn event(self: *System, engine: Engine) void
pub fn deinit(self: *System, engine: Engine) void
```

### Method Responsibilities

#### `init(self: *System, engine: Engine)`
- **Purpose**: Initialize system state and resources
- **Called**: Once at engine startup
- **Access**: Full engine state for cross-system initialization
- **Example**: Allocate buffers, load assets, setup GPU resources

#### `tick(self: *System, engine: Engine)`  
- **Purpose**: Update system logic and state
- **Called**: Every frame before rendering
- **Access**: Read/write system state, read other systems
- **Example**: Physics simulation, input processing, game logic

#### `draw(self: *System, engine: Engine)`
- **Purpose**: Render system output
- **Called**: Every frame after tick
- **Access**: Read system state, GPU commands
- **Example**: Mesh rendering, UI drawing, debug visualization

#### `event(self: *System, engine: Engine)`
- **Purpose**: Handle input and system events
- **Called**: When events occur (input, window, etc.)
- **Access**: Current event via `engine.event`
- **Example**: Key presses, mouse movement, window resize

#### `deinit(self: *System, engine: Engine)`
- **Purpose**: Cleanup resources and save state
- **Called**: Once at engine shutdown
- **Access**: System state for cleanup
- **Example**: Free memory, save files, destroy GPU resources

## System-Specific Interfaces

### World System Interface

World systems provide voxel data and mesh generation:

```zig
pub fn get(self: *World, x: i32, y: i32, z: i32) bool
pub fn mesh(self: *World, vertices: []Vertex, indices: []u16) Mesh
```

#### `get(x, y, z) -> bool`
- **Purpose**: Query voxel existence at coordinates
- **Performance**: Must be O(1) for physics queries
- **Bounds**: Return false for out-of-bounds coordinates
- **Usage**: Collision detection, visibility testing

#### `mesh(vertices, indices) -> Mesh`
- **Purpose**: Generate renderable mesh from voxel data
- **Output**: Fills provided vertex/index buffers
- **Return**: Slice views of actual data used
- **Optimization**: Should minimize face count via culling/merging

### Physics System Interface

Physics systems handle player movement and collision:

```zig
pub fn view(self: *Physics) Mat4
pub fn mouse(self: *Physics, dx: f32, dy: f32) void
```

#### `view() -> Mat4`
- **Purpose**: Generate camera view matrix
- **Format**: Column-major 4x4 transformation matrix
- **Usage**: Rendering pipeline for MVP transformation
- **Performance**: Called every frame, should be fast

#### `mouse(dx, dy)`
- **Purpose**: Handle mouse movement for camera control
- **Parameters**: Delta movement in pixels
- **Behavior**: Update camera orientation based on input
- **Constraints**: Apply pitch limits, sensitivity scaling

### Render System Interface

Render systems are parameterized by shader type:

```zig
pub fn Gfx(comptime ShaderType: type) type {
    return struct {
        // Renderer implementation specialized for ShaderType
    };
}
```

#### Shader Type Requirements
```zig
pub fn desc(backend: sg.Backend) sg.ShaderDesc
```

The shader must provide a descriptor function that returns appropriate shader bytecode for the target graphics backend.

### Input System Interface

Input systems manage device state:

```zig
pub fn forward(self: *Input) bool
pub fn back(self: *Input) bool  
pub fn left(self: *Input) bool
pub fn right(self: *Input) bool
pub fn jump(self: *Input) bool
pub fn crouch(self: *Input) bool
```

These methods provide semantic input queries rather than raw key states, enabling input remapping and multiple input sources.

## Implementation Examples

### Minimal System Template

```zig
pub const MySystem = struct {
    // System state
    value: f32,
    
    pub fn init(self: *MySystem, engine: anytype) void {
        self.* = .{ .value = 0.0 };
    }
    
    pub fn tick(self: *MySystem, engine: anytype) void {
        self.value += engine.dt;
    }
    
    pub fn draw(self: *MySystem, engine: anytype) void {
        // Rendering code
    }
    
    pub fn event(self: *MySystem, engine: anytype) void {
        // Event handling
    }
    
    pub fn deinit(self: *MySystem, engine: anytype) void {
        // Cleanup
    }
};
```

### Cross-System Communication

Systems communicate through the shared engine state:

```zig
pub fn tick(self: *MySystem, engine: anytype) void {
    // Read from other systems
    const player_pos = engine.systems.body.pos;
    const is_jumping = engine.systems.keys.jump();
    
    // Update own state based on other systems
    if (is_jumping) {
        self.jump_sound_timer = 0.5;
    }
}
```

### Compile-Time System Selection

Systems can be swapped at compile time:

```zig
const Engine = struct {
    systems: struct {
        // Choose world implementation
        world: if (GREEDY_MESHING) 
            engma.world.greedy 
        else 
            engma.world.voxel,
            
        // Choose physics implementation  
        body: if (QUAKE_PHYSICS)
            engma.player.quake
        else
            engma.player.basic,
    },
};
```

## Interface Benefits

### Uniform Orchestration
The engine can call methods on all systems uniformly:

```zig
engine.call("tick");  // Calls tick() on all systems
engine.call("draw");  // Calls draw() on all systems
```

### Compile-Time Verification
Interface compliance is verified at compile time - missing methods cause compilation errors.

### Zero Runtime Cost
No virtual function calls or dynamic dispatch - all method calls are direct and inlinable.

### System Isolation
Each system is self-contained with clear boundaries and dependencies.

### Easy Testing
Systems can be tested in isolation by providing mock engine state.

This interface design achieves the minimalist goal of maximum functionality with minimum complexity, enabling both performance and maintainability.