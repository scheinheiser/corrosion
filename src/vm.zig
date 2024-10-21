const std = @import("std");
const Chunk = @import("chunk.zig");
const Debug = @import("debug.zig");

const debug_trace_execution = true;

const InterpretResult = enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
};

pub const VirtualMachine = struct {
    const Self = @This();

    chunk: *Chunk.Chunk,
    instruction_pointer: usize,

    pub fn initVM() VirtualMachine {
        return VirtualMachine{
            .chunk = undefined,
            .instruction_pointer = undefined,
        };
    }

    pub fn deinitVM() void {}

    pub fn interpret(self: *Self, chunk: *Chunk.Chunk) InterpretResult {
        self.chunk = chunk;
        self.instruction_pointer = 0;

        return self.run();
    }

    fn run(self: *Self) InterpretResult {
        if (comptime debug_trace_execution) {
            _ = Debug.dissassembleInstruction(self.chunk.*, self.instruction_pointer);
        }

        while (true) {
            const value: Chunk.OpCode = @enumFromInt(self.getNextByte());
            switch (value) {
                .op_return => return InterpretResult.OK,
                .op_const => {
                    const constant = self.chunk.constants.items[self.getNextByte()];
                    std.debug.print("{d:.3}\n", .{constant});
                },
                else => {},
            }
        }
    }

    fn getNextByte(self: *Self) u8 {
        const byte = self.chunk.code.items[self.instruction_pointer];
        self.instruction_pointer += 1;

        return byte;
    }
};
