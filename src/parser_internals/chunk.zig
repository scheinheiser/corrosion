const std = @import("std");
const mem = @import("memory.zig");
const val = @import("value.zig");

const Value = val.Value;

pub const OpCode = enum {
    op_const,

    op_negate,
    op_abs,
    op_add,
    op_subtract,
    op_multiply,
    op_divide,
    op_mod,

    op_print,
    op_pop,

    op_defconst_global,
    op_defvar_global,

    op_get_global,
    op_set_global,
    op_get_local,
    op_set_local,

    op_not,
    op_greater,
    op_greater_eql,
    op_less,
    op_less_eql,
    op_equal,

    op_nil,
    op_true,
    op_false,

    op_jump_if_false,
    op_jump,
    op_loop,

    op_return,
    blank,
};

pub const Chunk = struct {
    const Self = @This();

    code: mem.DynArray(u8),
    lines: mem.DynArray(i32),
    constants: mem.DynArray(Value),

    pub fn initChunk() Self {
        return Self{
            .code = mem.DynArray(u8).initArr(),
            .lines = mem.DynArray(i32).initArr(),
            .constants = mem.DynArray(Value).initArr(),
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
            self.code.growCapacity();
            self.lines.growCapacity();

            self.code.growArray(self.code.capacity);
            self.lines.growArray(self.lines.capacity);
        }

        self.code.items[self.code.count] = data;
        self.lines.items[self.lines.count] = line;

        self.code.count += 1;
        self.lines.count += 1;
    }

    pub fn addConstant(self: *Self, value: Value) u8 {
        if (self.constants.capacity < self.constants.count + 1) {
            self.constants.growCapacity();

            self.constants.growArray(self.constants.capacity);
        }

        self.constants.items[self.constants.count] = value;
        self.constants.count += 1;

        const constant_idx: u8 = @intCast(self.constants.count - 1);
        return constant_idx;
    }
};
