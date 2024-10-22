const std = @import("std");
const chk = @import("chunk.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");

const Chunk = chk.Chunk;
const Opcode = chk.OpCode;
const VM = vm.VirtualMachine;

pub fn main() void {
    var chunk = Chunk.initChunk();
    // var virtual = VM.initVM();

    var constant = chunk.addConstant(10);
    chunk.writeToChunk(@intFromEnum(Opcode.op_const), 199);
    chunk.writeToChunk(constant, 199);

    constant = chunk.addConstant(20);
    chunk.writeToChunk(@intFromEnum(Opcode.op_const), 199);
    chunk.writeToChunk(constant, 199);

    chunk.writeToChunk(@intFromEnum(Opcode.op_add), 199);

    constant = chunk.addConstant(30);
    chunk.writeToChunk(@intFromEnum(Opcode.op_const), 199);
    chunk.writeToChunk(constant, 199);

    chunk.writeToChunk(@intFromEnum(Opcode.op_divide), 199);
    chunk.writeToChunk(@intFromEnum(Opcode.op_return), 199);

    debug.dissassembleChunk(chunk, "test chunk");
    // _ = virtual.interpret(&chunk);
    chunk.freeChunk();
}
