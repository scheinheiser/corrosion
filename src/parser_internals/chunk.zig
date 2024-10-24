const std = @import("std");
const mem = @import("memory.zig");

pub const OpCode = enum {
    op_const,

    op_negate,
    op_abs,
    op_add,
    op_subtract,
    op_multiply,
    op_divide,

    op_return,
    blank,
};

pub const Chunk = struct {
    const Self = @This();

    code: mem.DynArray(u8),
    lines: mem.DynArray(i32),
    constants: mem.DynArray(f32),

    pub fn initChunk() Self {
        return Self{
            .code = mem.DynArray(u8).initArr(),
            .lines = mem.DynArray(i32).initArr(),
            .constants = mem.DynArray(f32).initArr(),
        };
    }

    pub fn freeChunk(self: *Self) void {
        self.code.freeArray();
        self.lines.freeArray();
        self.constants.freeArray();

        self.* = initChunk();
    }

    pub fn writeToChunk(self: *Self, data: u8, line: i32) void {
        if (self.code.capacity < self.code.count + 1) {
            const new_capacity = self.code.growCapacity();

            self.code.growArray(new_capacity);
            self.lines.growArray(new_capacity);
        }

        self.code.items[self.code.count] = data;
        self.lines.items[self.code.count] = line;

        self.code.count += 1;
    }

    pub fn addConstant(self: *Self, value: f32) u8 {
        if (self.constants.capacity < self.constants.count + 1) {
            const new_capacity = self.constants.growCapacity();

            self.constants.growArray(new_capacity);
        }

        self.constants.items[self.constants.count] = value;
        self.constants.count += 1;

        const constant_idx: u8 = @intCast(self.constants.count - 1);
        return constant_idx;
    }
};
