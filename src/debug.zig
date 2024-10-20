const std = @import("std");
const Chunk = @import("chunk.zig");

pub fn dissassembleChunk(chunk: Chunk.Chunk, name: []const u8) void {
    std.debug.print("==== {s} ====\n", .{name});
    var offset: usize = 0;

    while (offset < chunk.code.count) {
        offset = dissassembleInstruction(chunk, offset);
    }
}

fn dissassembleInstruction(chunk: Chunk.Chunk, offset: usize) usize {
    std.debug.print("{b} ", .{offset});

    const instruction: Chunk.OpCode = @enumFromInt(chunk.code.arr[offset]);
    switch (instruction) {
        .op_return => return simpleInstruction("OP_RETURN", offset),
        else => {
            std.debug.print("Unrecognised opcode -> {any}", .{instruction});
            return offset + 1;
        },
    }
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}
