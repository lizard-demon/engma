const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const simgui = sokol.imgui;
const ig = @import("cimgui");
const math = @import("math.zig");

pub fn Gfx(comptime ShaderType: type) type {
    return struct {
        pipe: sg.Pipeline,
        bind: sg.Bindings,
        pass: sg.PassAction,
        count: u32,
        proj: math.Mat4,
        shader: sg.Shader,

        pub fn init(self: *@This(), _: anytype) void {
            if (!sg.isvalid()) {
                sg.setup(.{ .environment = sokol.glue.environment() });
                simgui.setup(.{});
            }
            self.* = .{
                .pipe = sg.Pipeline{},
                .bind = sg.Bindings{},
                .pass = sg.PassAction{},
                .count = 0,
                .proj = math.perspective(std.math.degreesToRadians(90), 4.0 / 3.0, 0.1, 100),
                .shader = sg.Shader{},
            };
        }

        pub fn draw(self: *@This(), state: anytype) void {
            if (self.count == 0) {
                self.cleanup();
                var verts: [32768]math.Vertex = undefined;
                var idx: [49152]u16 = undefined;
                const mesh = state.systems.world.mesh(&verts, &idx);

                var layout = sg.VertexLayoutState{};
                layout.attrs[0].format = .FLOAT3;
                layout.attrs[1].format = .FLOAT4;

                self.shader = sg.makeShader(ShaderType.desc(sg.queryBackend()));
                self.pipe = sg.makePipeline(.{
                    .shader = self.shader,
                    .layout = layout,
                    .index_type = .UINT16,
                    .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true },
                    .cull_mode = .BACK,
                });
                self.bind = .{
                    .vertex_buffers = .{ sg.makeBuffer(.{ .data = sg.asRange(mesh.vertices) }), .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                    .index_buffer = sg.makeBuffer(.{ .usage = .{ .index_buffer = true }, .data = sg.asRange(mesh.indices) }),
                };
                self.pass = .{ .colors = .{ .{ .load_action = .CLEAR, .clear_value = .{ .r = 0.1, .g = 0.1, .b = 0.2, .a = 1 } }, .{}, .{}, .{}, .{}, .{}, .{}, .{} } };
                self.count = @intCast(mesh.indices.len);
            }

            simgui.newFrame(.{ .width = sapp.width(), .height = sapp.height(), .delta_time = sapp.frameDuration() });

            sg.beginPass(.{ .action = self.pass, .swapchain = sokol.glue.swapchain() });
            sg.applyPipeline(self.pipe);
            sg.applyBindings(self.bind);

            const mvp = math.Mat4.mul(self.proj, state.systems.body.view());
            sg.applyUniforms(0, sg.asRange(&mvp));
            sg.draw(0, self.count, 1);

            const w = @as(f32, @floatFromInt(sapp.width()));
            const h = @as(f32, @floatFromInt(sapp.height()));
            const cx, const cy = .{ w * 0.5, h * 0.5 };

            ig.igSetNextWindowPos(.{ .x = 0, .y = 0 }, ig.ImGuiCond_Always);
            ig.igSetNextWindowSize(.{ .x = w, .y = h }, ig.ImGuiCond_Always);
            _ = ig.igBegin("##cross", null, ig.ImGuiWindowFlags_NoTitleBar | ig.ImGuiWindowFlags_NoResize | ig.ImGuiWindowFlags_NoMove | ig.ImGuiWindowFlags_NoBackground | ig.ImGuiWindowFlags_NoInputs);

            const dl = ig.igGetWindowDrawList();
            ig.ImDrawList_AddLine(dl, .{ .x = cx - 10, .y = cy }, .{ .x = cx + 10, .y = cy }, 0xFFFFFFFF);
            ig.ImDrawList_AddLine(dl, .{ .x = cx, .y = cy - 10 }, .{ .x = cx, .y = cy + 10 }, 0xFFFFFFFF);
            ig.igEnd();

            simgui.render();
            sg.endPass();
            sg.commit();
        }

        fn cleanup(self: *@This()) void {
            if (self.count > 0) {
                if (self.bind.vertex_buffers[0].id != 0) sg.destroyBuffer(self.bind.vertex_buffers[0]);
                if (self.bind.index_buffer.id != 0) sg.destroyBuffer(self.bind.index_buffer);
                if (self.pipe.id != 0) sg.destroyPipeline(self.pipe);
                if (self.shader.id != 0) sg.destroyShader(self.shader);
                self.count = 0;
            }
        }

        pub fn deinit(self: *@This(), _: anytype) void {
            self.cleanup();
            simgui.shutdown();
            sg.shutdown();
        }

        pub fn tick(_: *@This(), _: anytype) void {}
        pub fn event(_: *@This(), _: anytype, _: anytype) void {}
    };
}
