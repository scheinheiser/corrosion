const std = @import("std");
const Chunk = @import("parser_internals/chunk.zig");
const Log = @import("logger.zig");

const Logger = Log.Logger;
const LogLevel = Log.LogLevel;

pub fn dissassembleChunk(chunk: Chunk.Chunk, name: []const u8) void {
    std.debug.print("==== {s} ====\n", .{name});
    var offset: usize = 0;

    while (offset < chunk.code.count) {
        offset = dissassembleInstruction(chunk, offset);
    }
}

pub fn dissassembleInstruction(chunk: Chunk.Chunk, offset: usize) usize {
    std.debug.print("{b} ", .{offset});
    if (offset > 0 and chunk.lines.items[offset] == chunk.lines.items[offset - 1]) {
        std.debug.print("      |  ", .{});
    } else {
        std.debug.print("      {d} ", .{chunk.lines.items[offset]});
    }

    const instruction: Chunk.OpCode = @enumFromInt(chunk.code.items[offset]);
    switch (instruction) {
        .op_return => return simpleInstruction("OP_RETURN", offset),
        .op_const => return constantInstruction("OP_CONSTANT", chunk, offset),
        .op_negate => return simpleInstruction("OP_NEGATE", offset),
        .op_abs => return simpleInstruction("OP_ABSOLUTE", offset),
        .op_add => return simpleInstruction("OP_ADD", offset),
        .op_subtract => return simpleInstruction("OP_SUBTRACT", offset),
        .op_multiply => return simpleInstruction("OP_MULTIPLY", offset),
        .op_divide => return simpleInstruction("OP_DIVIDE", offset),
        else => {
            Logger.log(LogLevel.Warn, .Debug, "Unrecognised opcode -> {any}\n", .{instruction});
            return offset + 1;
        },
    }
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, chunk: Chunk.Chunk, offset: usize) usize {
    const constant = chunk.code.items[offset + 1];
    std.debug.print("{s}       {d} '{d:.3}'\n", .{ name, constant, chunk.constants.items[constant] });

    return offset + 2;
}
