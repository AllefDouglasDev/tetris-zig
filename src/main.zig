const std = @import("std");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
    @cInclude("OpenGL/gl3.h");
});

const vertex_shader_src =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\uniform vec2 uOffset;
    \\void main() {
    \\    gl_Position = vec4(aPos.xy + uOffset, aPos.z, 1.0);
    \\}
;

const fragment_shader_src =
    \\#version 330 core
    \\out vec4 FragColor;
    \\uniform vec3 uColor;
    \\void main() {
    \\    FragColor = vec4(uColor, 1.0f);
    \\}
;

const width: f32 = 800;
const height: f32 = 800;
const square_amount = 10;
const square_size_px = width / square_amount;
const half_square_size_ndc = px_to_ndc(square_size_px);
const square_size_ndc = half_square_size_ndc * 2;

pub fn main(init: std.process.Init) !void {
    if (c.glfwInit() == 0) {
        std.log.err("Failed to initialize GLFW", .{});
        return error.GlfwInitFailed;
    }
    defer c.glfwTerminate();
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GLFW_TRUE);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(width, height, "Tetris", null, null) orelse return error.WindowCreatingPkg;
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
    const v_src_ptr: ?[*]const u8 = vertex_shader_src.ptr;
    const v_src_len: c.GLint = @intCast(vertex_shader_src.len);
    c.glShaderSource(vertex_shader, 1, &v_src_ptr, &v_src_len);
    c.glCompileShader(vertex_shader);

    const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    const f_src_ptr: ?[*]const u8 = fragment_shader_src.ptr;
    const f_src_len: c.GLint = @intCast(fragment_shader_src.len);
    c.glShaderSource(fragment_shader, 1, &f_src_ptr, &f_src_len);
    c.glCompileShader(fragment_shader);

    const shader_program = c.glCreateProgram();
    c.glAttachShader(shader_program, vertex_shader);
    c.glAttachShader(shader_program, fragment_shader);
    c.glLinkProgram(shader_program);

    // Clean up
    c.glDeleteShader(vertex_shader);
    c.glDeleteShader(fragment_shader);

    std.log.debug("square_size_px {d}\nhalf_square_size_ndc {d:.4}\nsquare_size_ndc {d:.4}", .{ square_size_px, half_square_size_ndc, square_size_ndc });

    const vertices = [_]f32{
        half_square_size_ndc, half_square_size_ndc, 0.0, // Top right
        half_square_size_ndc, -half_square_size_ndc, 0.0, // Bottom right
        -half_square_size_ndc, -half_square_size_ndc, 0.0, // Bottom left
        -half_square_size_ndc, half_square_size_ndc, 0.0, // Top left
    };

    const indices = [_]u32{
        0, 1, 3, // Triangle 1
        1, 2, 3, // Triangle 2
    };

    var vao: u32 = 0;
    var vbo: u32 = 0;
    var ebo: u32 = 0;
    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &vbo);
    c.glGenBuffers(1, &ebo);

    c.glBindVertexArray(vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, c.GL_STATIC_DRAW);

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(f32) * indices.len, &indices, c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
    c.glEnableVertexAttribArray(0);

    const offset_loc = c.glGetUniformLocation(shader_program, "uOffset");
    const u_color_loc = c.glGetUniformLocation(shader_program, "uColor");

    const io = init.io;
    var last_time = std.Io.Clock.now(.awake, io).toMilliseconds();
    var fall_velocity_sec: f32 = 1;
    const move_velocity_sec: f32 = 0.09;
    var fall_spent_sec: f32 = 0;
    var move_block_spent_sec: f32 = 0;
    var active_block = create_block(.t, .{ .x = 3, .y = 0 });

    while (c.glfwWindowShouldClose(window) == 0) {
        const current_time = std.Io.Clock.now(.awake, io).toMilliseconds();
        const dt = current_time - last_time;
        last_time = current_time;
        fall_spent_sec += @as(f32, @floatFromInt(dt)) / 1000.0;
        move_block_spent_sec += @as(f32, @floatFromInt(dt)) / 1000.0;

        const d_key = c.glfwGetKey(window, c.GLFW_KEY_D);
        const a_key = c.glfwGetKey(window, c.GLFW_KEY_A);
        const s_key = c.glfwGetKey(window, c.GLFW_KEY_S);
        if (move_block_spent_sec > move_velocity_sec) {
            move_block_spent_sec = 0;
            if (d_key == c.GLFW_PRESS) {
                active_block.pos.x += 1;
            }
            if (a_key == c.GLFW_PRESS) {
                active_block.pos.x -= 1;
            }
            if (active_block.pos.x < 0) {
                active_block.pos.x = 0;
            }
            if (active_block.pos.x > square_amount - active_block.getSize().x) {
                active_block.pos.x = square_amount - active_block.getSize().x;
            }
        }

        if (s_key == c.GLFW_PRESS) {
            fall_velocity_sec = 0.2;
        } else {
            fall_velocity_sec = 1.0;
        }

        if (fall_spent_sec > fall_velocity_sec) {
            fall_spent_sec = 0;
            if (active_block.pos.y >= (square_amount - active_block.getSize().y)) {
                active_block.pos.y = square_amount - active_block.getSize().y;
            } else {
                active_block.pos.y += 1;
            }
        }

        c.glClearColor(0.15, 0.15, 0.15, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(shader_program);
        c.glBindVertexArray(vao);

        draw_block(offset_loc, u_color_loc, active_block);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    // final clean up
    c.glDeleteVertexArrays(1, &vao);
    c.glDeleteBuffers(1, &vbo);
    c.glDeleteBuffers(1, &ebo);
    c.glDeleteProgram(shader_program);
}

const Vec2 = struct {
    x: f32,
    y: f32,
};

const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

const BlockType = enum {
    j, l, t, o, z, s, i,
};

const BlockOrientation = enum(i8) {
    up = 0,
    down = 1,
    right = 2,
    left = 3,
};

fn create_block(block_type: BlockType, pos: Vec2) Block {
    return switch (block_type) {
        .j => .{
            .shape = .{ 1, 0, 0, 0, 1, 1, 1, 0 },
            .color = .{
                .x = 0.0, // Blue
                .y = 0.0,
                .z = 1.0,
            },
            .pos = pos, // Adjust coordinates to fit your game loop
            .orientation = .up,
        },
        .l => .{
            .shape = .{ 0, 0, 1, 0, 1, 1, 1, 0 },
            .color = .{
                .x = 1.0, // Orange
                .y = 0.5,
                .z = 0.0,
            },
            .pos = pos,
            .orientation = .up,
        },
        .t => .{
            .shape = .{ 0, 1, 0, 0, 1, 1, 1, 0 },
            .color = .{
                .x = 0.5, // Purple
                .y = 0.0,
                .z = 0.5,
            },
            .pos = pos,
            .orientation = .up,
        },
        .o => .{
            .shape = .{ 1, 1, 0, 0, 1, 1, 0, 0 },
            .color = .{
                .x = 1.0, // Yellow
                .y = 1.0,
                .z = 0.0,
            },
            .pos = pos,
            .orientation = .up,
        },
        .z => .{
            .shape = .{ 1, 1, 0, 0, 0, 1, 1, 0 },
            .color = .{
                .x = 1.0, // Red
                .y = 0.0,
                .z = 0.0,
            },
            .pos = pos,
            .orientation = .up,
        },
        .s => .{
            .shape = .{ 0, 1, 1, 0, 1, 1, 0, 0 },
            .color = .{
                .x = 0.0, // Green
                .y = 1.0,
                .z = 0.0,
            },
            .pos = pos,
            .orientation = .up,
        },
        .i => .{
            .shape = .{ 0, 0, 0, 0, 1, 1, 1, 1 },
            .color = .{
                .x = 0.0, // Cyan
                .y = 1.0,
                .z = 1.0,
            },
            .pos = pos,
            .orientation = .up,
        },
    };
}

const Block = struct {
    shape: [8]i8,
    color: Vec3,
    pos: Vec2,
    orientation: BlockOrientation,

    fn getSize(self: Block) Vec2 {
        var first_line: i8 = 0;
        var second_line: i8 = 0;
        for (self.shape, 0..) |val, idx| {
            if (val == 0) continue;
            if (idx < 4) first_line += 1 else second_line += 1;
        }
        const x: i8 = if (first_line > second_line) first_line else second_line;
        var y: i8 = 0;
        if (first_line > 0) y += 1;
        if (second_line > 0) y += 1;
        return .{
            .x = x,
            .y = y,
        };
    }
};

fn pos_to_ndc(pos: Vec2) Vec2 {
    const x_init_pos = -1 + half_square_size_ndc;
    const y_init_pos = 1 - half_square_size_ndc;
    const x = x_init_pos + (pos.x * square_size_ndc);
    const y = y_init_pos - (pos.y * square_size_ndc);
    return .{
        .x = x,
        .y = y,
    };
}

fn draw_block(offset_loc: i32, u_color_loc: i32, b: Block) void {
    const end_of_line = 3;
    var col: f32 = 0;
    var row: f32 = 0;
    for (b.shape, 0..) |val, i| {
        if (val == 0) {
            c.glUniform3f(u_color_loc, 0.1, 0.1, 0.1);
        } else {
            c.glUniform3f(u_color_loc, b.color.x, b.color.y, b.color.z);
        }
        const pos_ndc = pos_to_ndc(.{ .x = b.pos.x + col, .y = b.pos.y + row });
        c.glUniform2f(offset_loc, pos_ndc.x, pos_ndc.y);
        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
        col += 1;
        if (i == end_of_line) {
            col = 0;
            row = 1;
        }
    }
}

/// Pixel to Normalized Device Coordinates (-1..1)
fn px_to_ndc(px: f32) f32 {
    return px / width;
}
