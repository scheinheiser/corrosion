const std = @import("std");
const Chunk = @import("chunk.zig");
const Debug = @import("../debug.zig");
const Compiler = @import("compiler.zig");
const Log = @import("../logger.zig");
const Val = @import("value.zig");
const obj = @import("obj.zig");
const tbl = @import("table.zig");

const Logger = Log.Logger;
const Value = Val.Value;
const Obj = obj.Obj;
const ObjType = obj.ObjType;
const Table = tbl.Table;

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

    stack: [stack_max]Value,
    stack_top: usize,

    strings: Table,
    objects: ?*Obj,

    allocator: std.mem.Allocator,

    pub fn initVM() VirtualMachine {
        var temp = VirtualMachine{
            .chunk = undefined,
            .ip = undefined,
            .stack = undefined,
            .stack_top = undefined,
            .strings = Table.init(),
            .objects = null,
            .allocator = std.heap.page_allocator,
        };

        temp.resetStack();
        return temp;
    }

    pub fn deinitVM(self: *Self) void {
        self.strings.deinit();
        self.freeObjects();
    }

    fn freeObjects(self: *Self) void {
        var object = self.objects;

        while (object != null) {
            const next = object.?.next;
            obj.String.deinit(object.?, self);
            object = next;
        }
    }

    inline fn resetStack(self: *Self) void {
        self.stack_top = 0;
    }

    fn runtimeError(self: *Self, comptime text: []const u8, args: anytype) void {
        Logger.log(std.log.Level.err, .VM, text, args);
        Logger.log(std.log.Level.err, .VM, "[line {d}] in script.", .{self.chunk.lines.items[self.ip]});

        self.resetStack();
    }

    pub fn interpret(self: *Self, source: []const u8) InterpretResult {
        var chunk = Chunk.Chunk.initChunk();
        defer chunk.freeChunk();

        const comp_res = Compiler.compile(source, self, &chunk);
        if (!comp_res) {
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
                for (self.stack) |*stack_value| {
                    std.debug.print("[  {d:.3}  ]", .{stack_value.asNumber()});
                }
                std.debug.print("\n", .{});

                _ = Debug.dissassembleInstruction(self.chunk.*, self.ip);
            }

            const value: Chunk.OpCode = @enumFromInt(self.getNextByte());
            switch (value) {
                .op_return => {
                    var discarded_value = self.pop();
                    discarded_value.logValue();

                    return InterpretResult.OK;
                },
                .op_const => {
                    const constant = self.chunk.constants.items[self.getNextByte()];
                    self.push(constant);
                },
                .op_negate => {
                    if (!Value.isNum(self.peek(0))) {
                        self.runtimeError("Operand must be a number.", .{});
                        return InterpretResult.RUNTIME_ERROR;
                    }

                    const negated_value = self.pop().asNumber() * -1;
                    self.push(Value.makeNumber(negated_value));
                },
                .op_abs => self.push(Value.makeNumber(if (self.pop().asNumber() > 0) self.pop().asNumber() else self.pop().asNumber() * -1)),
                .op_subtract, .op_multiply, .op_divide, .op_greater, .op_less, .op_mod => |op| {
                    const res = self.binaryOperator(op);
                    if (res == .nil) {
                        self.runtimeError("The operands must be numbers.", .{});
                        return InterpretResult.RUNTIME_ERROR;
                    }

                    self.push(res);
                },
                .op_add => {
                    if (self.peek(0).isString() and self.peek(1).isString()) {
                        self.concatenate();
                    } else if (self.peek(0).isNum() and self.peek(1).isNum()) {
                        const res = self.binaryOperator(.op_add);
                        self.push(res);
                    } else {
                        self.runtimeError("Operands must both be strings or numbers.", .{});
                        return InterpretResult.RUNTIME_ERROR;
                    }
                },
                .op_nil => self.push(Value.makeNil()),
                .op_true => self.push(Value.makeBool(true)),
                .op_false => self.push(Value.makeBool(false)),
                .op_not => self.push(Value.makeBool(self.pop().isFalsey())),
                .op_equal => {
                    const value2 = self.pop();
                    const value1 = self.pop();

                    self.push(Value.makeBool(Value.checkEquality(&value1, &value2)));
                },
                else => {},
            }
        }
    }

    fn getNextByte(self: *Self) u8 {
        const byte = self.chunk.code.items[self.ip];
        self.ip += 1;

        return byte;
    }

    fn push(self: *Self, value: Value) void {
        self.stack[self.stack_top] = value;
        self.stack_top += 1;
    }

    fn pop(self: *Self) Value {
        self.stack_top -= 1;
        return self.stack[self.stack_top];
    }

    fn peek(self: *Self, dist: usize) Value {
        return self.stack[self.stack_top - dist - 1];
    }

    fn binaryOperator(self: *Self, op: Chunk.OpCode) Value {
        const value2 = self.pop().asNumber();
        const value1 = self.pop().asNumber();

        switch (op) {
            .op_add => return Value.makeNumber(value1 + value2),
            .op_subtract => return Value.makeNumber(value1 - value2),
            .op_multiply => return Value.makeNumber(value1 * value2),
            .op_divide => return Value.makeNumber(value1 / value2),
            .op_mod => return Value.makeNumber(@mod(value1, value2)),
            .op_less => return Value.makeBool(value1 < value2),
            .op_greater => return Value.makeBool(value1 > value2),
            else => unreachable,
        }
    }

    fn concatenate(self: *Self) void {
        const b = self.pop().asString();
        const a = self.pop().asString();

        const result = std.mem.concat(self.allocator, u8, &[_][]const u8{ a.characters, b.characters }) catch {
            Logger.log(std.log.Level.err, .Compiler, "Not enough memory to concatenate strings.", .{});
            std.process.exit(1);
        };

        const str = obj.String.takeString(self, result);
        self.push(Value.makeString(str));
    }
};
