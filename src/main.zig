const std = @import("std");
const chk = @import("chunk.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");

const Chunk = chk.Chunk;
const Opcode = chk.OpCode;
const VM = vm.VirtualMachine;

pub fn main() void {
    var chunk = Chunk.initChunk();
    var virtual = VM.initVM();

    const constant = chunk.addConstant(3.141592);
    chunk.writeToChunk(@intFromEnum(Opcode.op_const), 199);
    chunk.writeToChunk(constant, 199);
    chunk.writeToChunk(@intFromEnum(Opcode.op_return), 199);

    // debug.dissassembleChunk(chunk, "test chunk");
    _ = virtual.interpret(&chunk);
    chunk.freeChunk();
}
