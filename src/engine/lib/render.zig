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
        proj: math.Mat,
        shader: sg.Shader,
        engine_ref: ?*const anyopaque = null,

        pub fn init(allocator: std.mem.Allocator) Self {
            _ = allocator;
            // Check if graphics context is already initialized
            if (!sg.isvalid()) {
                sg.setup(.{ .environment = sokol.glue.environment() });
                simgui.setup(.{});
            }
            return .{ .pipe = sg.Pipeline{}, .bind = sg.Bindings{}, .pass = sg.PassAction{}, .count = 0, .proj = math.proj(90, 1.33, 0.1, 100), .shader = sg.Shader{}, .engine_ref = null };
        }

        pub fn setEngineRef(self: *Self, engine_ref: *const anyopaque) void {
            self.engine_ref = engine_ref;
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

        pub fn draw(self: *Self, world: anytype, view: math.Mat) void {
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
            sg.applyUniforms(0, sg.asRange(&math.Mat.mul(self.proj, view)));
            sg.draw(0, self.count, 1);

            // Cross
            const cx, const cy = .{ @as(f32, @floatFromInt(sapp.width())) * 0.5, @as(f32, @floatFromInt(sapp.height())) * 0.5 };
            ig.igSetNextWindowPos(.{ .x = 0, .y = 0 }, ig.ImGuiCond_Always);
            ig.igSetNextWindowSize(.{ .x = @floatFromInt(sapp.width()), .y = @floatFromInt(sapp.height()) }, ig.ImGuiCond_Always);
            _ = ig.igBegin("##cross", null, ig.ImGuiWindowFlags_NoTitleBar | ig.ImGuiWindowFlags_NoResize | ig.ImGuiWindowFlags_NoMove | ig.ImGuiWindowFlags_NoBackground | ig.ImGuiWindowFlags_NoInputs);
            const dl = ig.igGetWindowDrawList();
            ig.ImDrawList_AddLine(dl, .{ .x = cx - 10, .y = cy }, .{ .x = cx + 10, .y = cy }, 0xFFFFFFFF);
            ig.ImDrawList_AddLine(dl, .{ .x = cx, .y = cy - 10 }, .{ .x = cx, .y = cy + 10 }, 0xFFFFFFFF);
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
