const std = @import("std");
const Chunk = @import("chunk.zig");
const Debug = @import("../debug.zig");
const Compiler = @import("compiler.zig");
const Log = @import("../logger.zig");

const Logger = Log.Logger;
const LogLevel = Log.LogLevel;

const debug_trace_execution = false;
const stack_max: usize = 256;

const InterpretResult = enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
};

pub const VirtualMachine = struct {
    const Self = @This();

    chunk: *Chunk.Chunk,
    ip: usize,
    stack: [stack_max]f32,
    stack_top: usize,

    pub fn initVM() VirtualMachine {
        var temp = VirtualMachine{
            .chunk = undefined,
            .ip = undefined,
            .stack = undefined,
            .stack_top = undefined,
        };

        temp.resetStack();
        return temp;
    }

    inline fn resetStack(self: *Self) void {
        self.stack_top = 0;
    }

    pub fn deinitVM() void {}

    pub fn interpret(self: *Self, source: [:0]const u8) InterpretResult {
        const chunk = Chunk.Chunk.initChunk();
        defer chunk.freeChunk();

        if (!Compiler.ompile(source, &chunk)) {
            chunk.freeChunk();
            return InterpretResult.COMPILE_ERROR;
        }

        self.chunk = &chunk;
        self.ip = 0;

        return self.run();
    }

    fn run(self: *Self) InterpretResult {
        while (true) {
            if (comptime debug_trace_execution) {
                for (self.stack) |stack_value| {
                    std.debug.print("[  {d:.3}  ]", .{stack_value});
                }
                std.debug.print("\n", .{});

                _ = Debug.dissassembleInstruction(self.chunk.*, self.ip);
            }

            const value: Chunk.OpCode = @enumFromInt(self.getNextByte());
            switch (value) {
                .op_return => {
                    const discarded_value = self.pop();
                    Logger.log(LogLevel.Debug, .VM, "Pushed value = {d:.3}\n", .{discarded_value});

                    return InterpretResult.OK;
                },
                .op_const => {
                    const constant = self.chunk.constants.items[self.getNextByte()];
                    self.push(constant);
                    Logger.log(LogLevel.Debug, .VM, "{d:.3}\n", .{constant});
                },
                .op_negate => self.push(self.pop() * -1),
                .op_abs => self.push(if (self.pop() > 0) self.pop() else self.pop() * -1),
                .op_add => self.push(self.binaryOperator(.op_add)),
                .op_subtract => self.push(self.binaryOperator(.op_subtract)),
                .op_multiply => self.push(self.binaryOperator(.op_multiply)),
                .op_divide => self.push(self.binaryOperator(.op_divide)),
                else => {},
            }
        }
    }

    fn getNextByte(self: *Self) u8 {
        const byte = self.chunk.code.items[self.ip];
        self.ip += 1;

        return byte;
    }

    fn push(self: *Self, value: f32) void {
        self.stack[self.stack_top] = value;
        self.stack_top += 1;
    }

    fn pop(self: *Self) f32 {
        self.stack_top -= 1;
        return self.stack[self.stack_top];
    }

    fn binaryOperator(self: *Self, op: Chunk.OpCode) f32 {
        const operand2 = self.pop();
        const operand1 = self.pop();

        switch (op) {
            .op_add => return operand1 + operand2,
            .op_subtract => return operand1 - operand2,
            .op_multiply => return operand1 * operand2,
            .op_divide => return operand1 / operand2,
            else => unreachable,
        }
    }
};