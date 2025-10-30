// Sokol renderer - generic mesh rendering
const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const simgui = sokol.imgui;
const ig = @import("cimgui");
const math = @import("../lib/math.zig");

pub fn Gfx(comptime ShaderType: type) type {
    return struct {
        const Self = @This();

        pipe: sg.Pipeline,
        bind: sg.Bindings,
        pass: sg.PassAction,
        count: u32,
        proj: math.Mat,

        pub fn init() Self {
            sg.setup(.{ .environment = sokol.glue.environment() });
            simgui.setup(.{});
            return .{ .pipe = undefined, .bind = undefined, .pass = undefined, .count = 0, .proj = math.proj(90, 1.33, 0.1, 100) };
        }

        fn build(world: anytype) struct { pipe: sg.Pipeline, bind: sg.Bindings, pass: sg.PassAction, count: u32 } {
            var verts: [32768]math.Vertex = undefined;
            var idx: [49152]u16 = undefined;

            // Let the world generate its own mesh
            const mesh = world.mesh(&verts, &idx);

            var layout = sg.VertexLayoutState{};
            layout.attrs[0].format = .FLOAT3;
            layout.attrs[1].format = .FLOAT4;

            return .{ .pipe = sg.makePipeline(.{ .shader = sg.makeShader(ShaderType.desc(sg.queryBackend())), .layout = layout, .index_type = .UINT16, .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true }, .cull_mode = .BACK }), .bind = .{ .vertex_buffers = .{ sg.makeBuffer(.{ .data = sg.asRange(mesh.vertices) }), .{}, .{}, .{}, .{}, .{}, .{}, .{} }, .index_buffer = sg.makeBuffer(.{ .usage = .{ .index_buffer = true }, .data = sg.asRange(mesh.indices) }) }, .pass = .{ .colors = .{ .{ .load_action = .CLEAR, .clear_value = .{ .r = 0.1, .g = 0.1, .b = 0.2, .a = 1 } }, .{}, .{}, .{}, .{}, .{}, .{}, .{} } }, .count = @intCast(mesh.indices.len) };
        }

        pub fn draw(self: *Self, world: anytype, view: math.Mat) void {
            if (self.count == 0) {
                const m = build(world);
                self.* = .{ .pipe = m.pipe, .bind = m.bind, .pass = m.pass, .count = m.count, .proj = self.proj };
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

        pub fn dt(self: *Self) f32 {
            _ = self;
            return @floatCast(sapp.frameDuration());
        }
        pub fn deinit(self: *Self) void {
            _ = self;
            simgui.shutdown();
            sg.shutdown();
        }
    };
}
