const std = @import("std");
const chk = @import("chunk.zig");
const debug = @import("debug.zig");

const Chunk = chk.Chunk;
const Opcode = chk.OpCode;

pub fn main() void {
    var chunk = Chunk.initChunk();

    const constant = chunk.addConstant(3.141592);
    chunk.writeToChunk(@intFromEnum(Opcode.op_const), 199);
    chunk.writeToChunk(constant, 199);
    chunk.writeToChunk(@intFromEnum(Opcode.op_return), 199);

    debug.dissassembleChunk(chunk, "test chunk");
    chunk.freeChunk();
}
