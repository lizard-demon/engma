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

        pub fn init(_: std.mem.Allocator) Self {
            if (!sg.isvalid()) {
                sg.setup(.{ .environment = sokol.glue.environment() });
                simgui.setup(.{});
            }
            return .{
                .pipe = sg.Pipeline{},
                .bind = sg.Bindings{},
                .pass = sg.PassAction{},
                .count = 0,
                .proj = math.perspective(std.math.degreesToRadians(90), 4.0 / 3.0, 0.1, 100),
                .shader = sg.Shader{},
            };
        }

        const BuildResult = struct { pipe: sg.Pipeline, bind: sg.Bindings, pass: sg.PassAction, count: u32, shader: sg.Shader };

        fn build(world: anytype) BuildResult {
            var verts: [32768]math.Vertex = undefined;
            var idx: [49152]u16 = undefined;
            const mesh = world.mesh(&verts, &idx);

            var layout = sg.VertexLayoutState{};
            layout.attrs[0].format = .FLOAT3;
            layout.attrs[1].format = .FLOAT4;

            const shader = sg.makeShader(ShaderType.desc(sg.queryBackend()));
            const pipeline = sg.makePipeline(.{
                .shader = shader,
                .layout = layout,
                .index_type = .UINT16,
                .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true },
                .cull_mode = .BACK,
            });

            return .{
                .pipe = pipeline,
                .bind = .{
                    .vertex_buffers = .{ sg.makeBuffer(.{ .data = sg.asRange(mesh.vertices) }), .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                    .index_buffer = sg.makeBuffer(.{ .usage = .{ .index_buffer = true }, .data = sg.asRange(mesh.indices) }),
                },
                .pass = .{ .colors = .{ .{ .load_action = .CLEAR, .clear_value = .{ .r = 0.1, .g = 0.1, .b = 0.2, .a = 1 } }, .{}, .{}, .{}, .{}, .{}, .{}, .{} } },
                .count = @intCast(mesh.indices.len),
                .shader = shader,
            };
        }

        pub fn tick(_: *Self, _: f32) void {}

        pub fn event(_: *Self, _: anytype) void {}

        pub fn draw(self: *Self, world: anytype, view: math.Mat4) void {
            if (self.count == 0) {
                self.deinit_resources();
                const m = build(world);
                self.* = .{
                    .pipe = m.pipe,
                    .bind = m.bind,
                    .pass = m.pass,
                    .count = m.count,
                    .shader = m.shader,
                    .proj = self.proj,
                };
            }

            simgui.newFrame(.{ .width = sapp.width(), .height = sapp.height(), .delta_time = sapp.frameDuration() });

            sg.beginPass(.{ .action = self.pass, .swapchain = sokol.glue.swapchain() });
            sg.applyPipeline(self.pipe);
            sg.applyBindings(self.bind);

            const mvp = math.Mat4.mul(self.proj, view);
            sg.applyUniforms(0, sg.asRange(&mvp));
            sg.draw(0, self.count, 1);

            // Crosshair
            const w = @as(f32, @floatFromInt(sapp.width()));
            const h = @as(f32, @floatFromInt(sapp.height()));
            const cx, const cy = .{ w * 0.5, h * 0.5 };

            ig.igSetNextWindowPos(.{ .x = 0, .y = 0 }, ig.ImGuiCond_Always);
            ig.igSetNextWindowSize(.{ .x = w, .y = h }, ig.ImGuiCond_Always);
            _ = ig.igBegin("##cross", null, ig.ImGuiWindowFlags_NoTitleBar | ig.ImGuiWindowFlags_NoResize | ig.ImGuiWindowFlags_NoMove | ig.ImGuiWindowFlags_NoBackground | ig.ImGuiWindowFlags_NoInputs);

            const dl = ig.igGetWindowDrawList();
            const size = 10.0;
            const color = 0xFFFFFFFF;

            ig.ImDrawList_AddLine(dl, .{ .x = cx - size, .y = cy }, .{ .x = cx + size, .y = cy }, color);
            ig.ImDrawList_AddLine(dl, .{ .x = cx, .y = cy - size }, .{ .x = cx, .y = cy + size }, color);
            ig.igEnd();

            simgui.render();
            sg.endPass();
            sg.commit();
        }

        pub fn getDeltaTime(_: *Self) f32 {
            return @floatCast(sapp.frameDuration());
        }

        fn deinit_resources(self: *Self) void {
            if (self.count > 0) {
                if (self.bind.vertex_buffers[0].id != 0) sg.destroyBuffer(self.bind.vertex_buffers[0]);
                if (self.bind.index_buffer.id != 0) sg.destroyBuffer(self.bind.index_buffer);
                if (self.pipe.id != 0) sg.destroyPipeline(self.pipe);
                if (self.shader.id != 0) sg.destroyShader(self.shader);

                self.* = .{
                    .pipe = sg.Pipeline{},
                    .bind = sg.Bindings{},
                    .pass = sg.PassAction{},
                    .count = 0,
                    .proj = self.proj,
                    .shader = sg.Shader{},
                };
            }
        }

        pub fn deinit(self: *Self, _: std.mem.Allocator) void {
            self.deinit_resources();
        }
    };
}
