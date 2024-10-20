const std = @import("std");
const mem = @import("memory.zig");

pub const OpCode = enum {
    op_const,
    op_return,
};

pub const Chunk = struct {
    const Self = @This();

    code: mem.DynArray(u8),
    constants: mem.DynArray(f32),

    pub fn initChunk() Self {
        return Self{
            .code = mem.DynArray(u8).initArr(),
            .constants = mem.DynArray(f32).initArr(),
        };
    }

    pub fn freeChunk(self: *Self) void {
        _ = self.code.freeArray();
        _ = self.constants.freeArray();
        self.* = initChunk();
    }

    pub fn writeToChunk(self: *Self, data: u8) void {
        if (self.code.capacity < self.code.count + 1) {
            const new_capacity = self.code.growCapacity();

            _ = self.code.growArray(new_capacity);
        }

        self.code.arr[self.code.count] = data;
        self.code.count += 1;
    }

    fn addConstant(self: *Self, value: f32) usize {
        if (self.constants.capacity < self.constants.count + 1) {
            const new_capacity = self.constants.growCapacity();

            _ = self.constants.growArray(new_capacity);
        }

        self.constants.arr[self.constants.count] = value;
        self.constants.count += 1;

        return self.constants.count - 1;
    }
};
