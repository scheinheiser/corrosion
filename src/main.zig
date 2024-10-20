const std = @import("std");
const chk = @import("chunk.zig");
const debug = @import("debug.zig");

const Chunk = chk.Chunk;
const Opcode = chk.OpCode;

pub fn main() void {
    var chunk = Chunk.initChunk();

    chunk.writeToChunk(@intFromEnum(Opcode.op_return));

    debug.dissassembleChunk(chunk, "test chunk");
    chunk.freeChunk();
}
