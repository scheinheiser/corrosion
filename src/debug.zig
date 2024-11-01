const std = @import("std");
const val = @import("parser_internals/value.zig");
const Chunk = @import("parser_internals/chunk.zig");
const Log = @import("logger.zig");

const Logger = Log.Logger;
const Value = val.Value;

pub const Sign = enum {
    neg,
    pos,
};

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
        // .op_abs => return simpleInstruction("OP_ABSOLUTE", offset),
        .op_add => return simpleInstruction("OP_ADD", offset),
        .op_subtract => return simpleInstruction("OP_SUBTRACT", offset),
        .op_multiply => return simpleInstruction("OP_MULTIPLY", offset),
        .op_divide => return simpleInstruction("OP_DIVIDE", offset),
        .op_mod => return simpleInstruction("OP_MOD", offset),
        .op_nil => return simpleInstruction("OP_NIL", offset),
        .op_true => return simpleInstruction("OP_TRUE", offset),
        .op_false => return simpleInstruction("OP_FALSE", offset),
        .op_not => return simpleInstruction("OP_NOT", offset),
        .op_greater => return simpleInstruction("OP_GREATER", offset),
        .op_less => return simpleInstruction("OP_LESS", offset),
        .op_equal => return simpleInstruction("OP_EQUAL", offset),
        .op_print => return simpleInstruction("OP_PRINT", offset),
        .op_pop => return simpleInstruction("OP_POP", offset),
        .op_defconst_global => return constantInstruction("OP_DEFINE_CONSTANT_GLOBAL", chunk, offset),
        .op_defvar_global => return constantInstruction("OP_DEFINE_VARIABLE_GLOBAL", chunk, offset),
        .op_get_global => return constantInstruction("OP_GET_GLOBAL", chunk, offset),
        .op_set_global => return constantInstruction("OP_SET_GLOBAL", chunk, offset),
        .op_get_local => return byteInstruction("OP_GET_LOCAL", chunk, offset),
        .op_set_local => return byteInstruction("OP_SET_LOCAL", chunk, offset),
        .op_jump_if_false => return jumpInstruction("OP_JUMP_IF_FALSE", .pos, chunk, offset),
        .op_jump => return jumpInstruction("OP_JUMP", .pos, chunk, offset),
        .op_loop => return jumpInstruction("OP_LOOP", .neg, chunk, offset),
        else => {
            Logger.log(std.log.Level.warn, .Debug, @src(), "Unrecognised opcode -> {any}\n", .{instruction});
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
    std.debug.print("{s}       {d} ", .{ name, constant });

    var constant_value = &chunk.constants.items[constant];
    constant_value.printValue();

    return offset + 2;
}

fn byteInstruction(name: []const u8, chunk: Chunk.Chunk, offset: usize) usize {
    const slot = chunk.code.items[offset + 1];
    std.debug.print("{s}       {d}\n", .{ name, slot });

    return offset + 2;
}

fn jumpInstruction(name: []const u8, comptime sign: Sign, chunk: Chunk.Chunk, offset: usize) usize {
    var jump = @as(u16, chunk.code.items[offset + 1]) << 8;
    jump |= chunk.code.items[offset + 2];
    const jump_address = switch (sign) {
        .pos => offset + 3 + jump,
        .neg => offset + 3 - jump,
    };

    std.debug.print("{s}       {d} -> {d}\n", .{ name, offset, jump_address });
    return offset + 3;
}
