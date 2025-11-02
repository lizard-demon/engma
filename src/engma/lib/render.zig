const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const simgui = sokol.imgui;
const ig = @import("cimgui");
const math = @import("math.zig");

pub fn Gfx(comptime ShaderType: type) type {
    return struct {
        // Static world rendering
        world_pipe: sg.Pipeline,
        world_bind: sg.Bindings,
        world_count: u32,
        world_shader: sg.Shader,

        // Dynamic weapon rendering
        weapon_pipe: sg.Pipeline,
        weapon_bind: sg.Bindings,
        weapon_count: u32,
        weapon_shader: sg.Shader,

        pass: sg.PassAction,
        proj: math.Mat4,

        pub fn init(_: std.mem.Allocator) @This() {
            if (!sg.isvalid()) {
                sg.setup(.{ .environment = sokol.glue.environment() });
                simgui.setup(.{});
            }
            return .{
                .world_pipe = sg.Pipeline{},
                .world_bind = sg.Bindings{},
                .world_count = 0,
                .world_shader = sg.Shader{},
                .weapon_pipe = sg.Pipeline{},
                .weapon_bind = sg.Bindings{},
                .weapon_count = 0,
                .weapon_shader = sg.Shader{},
                .pass = sg.PassAction{},
                .proj = math.perspective(std.math.degreesToRadians(90), 4.0 / 3.0, 0.1, 100),
            };
        }

        pub fn draw(self: *@This(), world: anytype, weapons: anytype, view: math.Mat4) void {
            // Build static world mesh only once
            if (self.world_count == 0) {
                var verts: [32768]math.Vertex = undefined;
                var idx: [49152]u16 = undefined;
                const mesh = world.mesh(&verts, &idx);

                var layout = sg.VertexLayoutState{};
                layout.attrs[0].format = .FLOAT3;
                layout.attrs[1].format = .FLOAT4;

                self.world_shader = sg.makeShader(ShaderType.desc(sg.queryBackend()));
                self.world_pipe = sg.makePipeline(.{
                    .shader = self.world_shader,
                    .layout = layout,
                    .index_type = .UINT16,
                    .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true },
                    .cull_mode = .BACK,
                });
                self.world_bind = .{
                    .vertex_buffers = .{ sg.makeBuffer(.{ .data = sg.asRange(mesh.vertices) }), .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                    .index_buffer = sg.makeBuffer(.{ .usage = .{ .index_buffer = true }, .data = sg.asRange(mesh.indices) }),
                };
                self.world_count = @intCast(mesh.indices.len);
            }

            // Build dynamic weapon mesh every frame
            self.cleanupWeapons();
            var weapon_verts: [4096]math.Vertex = undefined;
            var weapon_idx: [6144]u16 = undefined;
            var vi: usize = 0;
            var ii: usize = 0;
            weapons.addVisuals(&weapon_verts, &weapon_idx, &vi, &ii);

            if (vi > 0) {
                var layout = sg.VertexLayoutState{};
                layout.attrs[0].format = .FLOAT3;
                layout.attrs[1].format = .FLOAT4;

                self.weapon_shader = sg.makeShader(ShaderType.desc(sg.queryBackend()));
                self.weapon_pipe = sg.makePipeline(.{
                    .shader = self.weapon_shader,
                    .layout = layout,
                    .index_type = .UINT16,
                    .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true },
                    .cull_mode = .BACK,
                });
                self.weapon_bind = .{
                    .vertex_buffers = .{ sg.makeBuffer(.{ .data = sg.asRange(weapon_verts[0..vi]) }), .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                    .index_buffer = sg.makeBuffer(.{ .usage = .{ .index_buffer = true }, .data = sg.asRange(weapon_idx[0..ii]) }),
                };
                self.weapon_count = @intCast(ii);
            }

            self.pass = .{ .colors = .{ .{ .load_action = .CLEAR, .clear_value = .{ .r = 0.1, .g = 0.1, .b = 0.2, .a = 1 } }, .{}, .{}, .{}, .{}, .{}, .{}, .{} } };

            simgui.newFrame(.{ .width = sapp.width(), .height = sapp.height(), .delta_time = sapp.frameDuration() });

            sg.beginPass(.{ .action = self.pass, .swapchain = sokol.glue.swapchain() });

            const mvp = math.Mat4.mul(self.proj, view);

            // Draw static world
            if (self.world_count > 0) {
                sg.applyPipeline(self.world_pipe);
                sg.applyBindings(self.world_bind);
                sg.applyUniforms(0, sg.asRange(&mvp));
                sg.draw(0, self.world_count, 1);
            }

            // Draw dynamic weapons
            if (self.weapon_count > 0) {
                sg.applyPipeline(self.weapon_pipe);
                sg.applyBindings(self.weapon_bind);
                sg.applyUniforms(0, sg.asRange(&mvp));
                sg.draw(0, self.weapon_count, 1);
            }

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

        pub fn getDeltaTime(_: *@This()) f32 {
            return @floatCast(sapp.frameDuration());
        }

        fn cleanupWeapons(self: *@This()) void {
            if (self.weapon_count > 0) {
                if (self.weapon_bind.vertex_buffers[0].id != 0) sg.destroyBuffer(self.weapon_bind.vertex_buffers[0]);
                if (self.weapon_bind.index_buffer.id != 0) sg.destroyBuffer(self.weapon_bind.index_buffer);
                if (self.weapon_pipe.id != 0) sg.destroyPipeline(self.weapon_pipe);
                if (self.weapon_shader.id != 0) sg.destroyShader(self.weapon_shader);
                self.weapon_count = 0;
            }
        }

        fn cleanup(self: *@This()) void {
            if (self.world_count > 0) {
                if (self.world_bind.vertex_buffers[0].id != 0) sg.destroyBuffer(self.world_bind.vertex_buffers[0]);
                if (self.world_bind.index_buffer.id != 0) sg.destroyBuffer(self.world_bind.index_buffer);
                if (self.world_pipe.id != 0) sg.destroyPipeline(self.world_pipe);
                if (self.world_shader.id != 0) sg.destroyShader(self.world_shader);
                self.world_count = 0;
            }
            self.cleanupWeapons();
        }

        pub fn deinit(self: *@This(), _: std.mem.Allocator) void {
            self.cleanup();
        }
    };
}
