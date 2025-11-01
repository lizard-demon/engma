// Sokol renderer - generic mesh rendering
const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const simgui = sokol.imgui;
const ig = @import("cimgui");
const math = @import("math.zig");

pub fn Gfx(comptime ShaderType: type) type {
    return struct {
        const Self = @This();

        pipe: sg.Pipeline,
        bind: sg.Bindings,
        pass: sg.PassAction,
        count: u32,
        proj: math.Mat4,
        shader: sg.Shader,

        pub fn init(allocator: std.mem.Allocator) Self {
            _ = allocator;
            // Check if graphics context is already initialized
            if (!sg.isvalid()) {
                sg.setup(.{ .environment = sokol.glue.environment() });
                simgui.setup(.{});
            }
            return .{ .pipe = sg.Pipeline{}, .bind = sg.Bindings{}, .pass = sg.PassAction{}, .count = 0, .proj = math.perspective(std.math.degreesToRadians(90.0), 4.0 / 3.0, 0.1, 100.0), .shader = sg.Shader{} };
        }

        const BuildResult = struct { pipe: sg.Pipeline, bind: sg.Bindings, pass: sg.PassAction, count: u32, shader: sg.Shader };

        fn build(world: anytype) BuildResult {
            var verts: [32768]math.Vertex = undefined;
            var idx: [49152]u16 = undefined;

            // Let the world generate its own mesh
            const mesh = world.mesh(&verts, &idx);

            var layout = sg.VertexLayoutState{};
            layout.attrs[0].format = .FLOAT3;
            layout.attrs[1].format = .FLOAT4;

            const shader = sg.makeShader(ShaderType.desc(sg.queryBackend()));
            const pipeline = sg.makePipeline(.{ .shader = shader, .layout = layout, .index_type = .UINT16, .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true }, .cull_mode = .BACK });
            const vertex_buffer = sg.makeBuffer(.{ .data = sg.asRange(mesh.vertices) });
            const index_buffer = sg.makeBuffer(.{ .usage = .{ .index_buffer = true }, .data = sg.asRange(mesh.indices) });

            return .{ .pipe = pipeline, .bind = .{ .vertex_buffers = .{ vertex_buffer, .{}, .{}, .{}, .{}, .{}, .{}, .{} }, .index_buffer = index_buffer }, .pass = .{ .colors = .{ .{ .load_action = .CLEAR, .clear_value = .{ .r = 0.1, .g = 0.1, .b = 0.2, .a = 1 } }, .{}, .{}, .{}, .{}, .{}, .{}, .{} } }, .count = @intCast(mesh.indices.len), .shader = shader };
        }

        pub fn tick(self: *Self, dt: f32) void {
            _ = self;
            _ = dt;
        }

        pub fn event(self: *Self, e: anytype) void {
            _ = self;
            _ = e;
        }

        pub fn draw(self: *Self, world: anytype, view: math.Mat4) void {
            if (self.count == 0) {
                // Clean up any existing resources first
                self.deinit_resources();

                const m = build(world);
                self.pipe = m.pipe;
                self.bind = m.bind;
                self.pass = m.pass;
                self.count = m.count;
                self.shader = m.shader;
            }

            simgui.newFrame(.{ .width = sapp.width(), .height = sapp.height(), .delta_time = sapp.frameDuration() });

            sg.beginPass(.{ .action = self.pass, .swapchain = sokol.glue.swapchain() });
            sg.applyPipeline(self.pipe);
            sg.applyBindings(self.bind);

            // Use Mat4 type for uniforms
            const mvp_mat4 = math.Mat4.mul(self.proj, view);
            sg.applyUniforms(0, sg.asRange(&mvp_mat4));
            sg.draw(0, self.count, 1);

            // Crosshair rendering with better type safety
            const screen_width = @as(f32, @floatFromInt(sapp.width()));
            const screen_height = @as(f32, @floatFromInt(sapp.height()));
            const cx = screen_width * 0.5;
            const cy = screen_height * 0.5;

            ig.igSetNextWindowPos(.{ .x = 0.0, .y = 0.0 }, ig.ImGuiCond_Always);
            ig.igSetNextWindowSize(.{ .x = screen_width, .y = screen_height }, ig.ImGuiCond_Always);
            _ = ig.igBegin("##cross", null, ig.ImGuiWindowFlags_NoTitleBar |
                ig.ImGuiWindowFlags_NoResize |
                ig.ImGuiWindowFlags_NoMove |
                ig.ImGuiWindowFlags_NoBackground |
                ig.ImGuiWindowFlags_NoInputs);

            const dl = ig.igGetWindowDrawList();
            const crosshair_size = 10.0;
            const crosshair_color = 0xFFFFFFFF;

            ig.ImDrawList_AddLine(dl, .{ .x = cx - crosshair_size, .y = cy }, .{ .x = cx + crosshair_size, .y = cy }, crosshair_color);
            ig.ImDrawList_AddLine(dl, .{ .x = cx, .y = cy - crosshair_size }, .{ .x = cx, .y = cy + crosshair_size }, crosshair_color);
            ig.igEnd();

            simgui.render();
            sg.endPass();
            sg.commit();
        }

        pub fn getDeltaTime(self: *Self) f32 {
            _ = self;
            return @floatCast(sapp.frameDuration());
        }
        fn deinit_resources(self: *Self) void {
            if (self.count > 0) {
                // Destroy GPU resources safely
                if (self.bind.vertex_buffers[0].id != 0) {
                    sg.destroyBuffer(self.bind.vertex_buffers[0]);
                }
                if (self.bind.index_buffer.id != 0) {
                    sg.destroyBuffer(self.bind.index_buffer);
                }
                if (self.pipe.id != 0) {
                    sg.destroyPipeline(self.pipe);
                }
                if (self.shader.id != 0) {
                    sg.destroyShader(self.shader);
                }

                // Reset state
                self.count = 0;
                self.pipe = sg.Pipeline{};
                self.bind = sg.Bindings{};
                self.shader = sg.Shader{};
            }
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            _ = allocator;
            self.deinit_resources();
        }
    };
}
