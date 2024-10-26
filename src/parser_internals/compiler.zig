const std = @import("std");
const sc = @import("scanner.zig");
const chk = @import("chunk.zig");
const Log = @import("../logger.zig");
const Debug = @import("../debug.zig");
const val = @import("value.zig");
const obj = @import("obj.zig");
const VirtualMachine = @import("vm.zig");

const Scanner = sc.Scanner;
const Chunk = chk.Chunk;
const Value = val.Value;
const Logger = Log.Logger;
const Obj = obj.Obj;
const VM = VirtualMachine.VirtualMachine;

const debug_print_code = true;

fn endCompiler(parser: *Parser) void {
    parser.*.emitReturn();
    if (comptime debug_print_code) {
        if (!parser.had_error) {
            Debug.dissassembleChunk(parser.currentChunk().*, "code");
        }
    }
}

pub fn compile(source: []const u8, vm: *VM, chunk: *Chunk) bool {
    const scanner = Scanner.init(source);
    var parser = Parser.init(scanner, chunk, vm);

    parser.advance();
    parser.expression();
    parser.consume(sc.Tag.EOF, "Expect end of expression.");

    endCompiler(&parser);
    return !parser.had_error;
}

pub const Precedence = enum {
    NONE,
    ASSIGNMENT,
    OR,
    AND,
    EQUALITY,
    COMPARISON,
    TERM,
    FACTOR,
    UNARY,
    CALL,
    PRIMARY,
};

const ParseFn = *const fn (parser: *Parser) void;

pub const ParseRule = struct {
    const Self = @This();

    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,

    pub fn init(prefix: ?ParseFn, infix: ?ParseFn, precedence: Precedence) ParseRule {
        return ParseRule{
            .prefix = prefix,
            .infix = infix,
            .precedence = precedence,
        };
    }
};

fn getRule(token_type: sc.Tag) ParseRule {
    return switch (token_type) {
        .leftbracket => ParseRule.init(Parser.grouping, null, Precedence.NONE),
        .subtract => ParseRule.init(Parser.unary, Parser.binary, Precedence.TERM),
        .plus => ParseRule.init(null, Parser.binary, Precedence.TERM),
        .divide, .multiply, .mod => ParseRule.init(null, Parser.binary, Precedence.FACTOR),
        .integer, .float => ParseRule.init(Parser.number, null, Precedence.NONE),
        .keyword_false, .keyword_true, .keyword_nil => ParseRule.init(Parser.literal, null, Precedence.NONE),
        .bang => ParseRule.init(Parser.unary, null, Precedence.NONE),
        .bang_equal, .equal_equal => ParseRule.init(null, Parser.binary, Precedence.EQUALITY),
        .greater_than, .greater_than_eql_to, .less_than, .less_than_eql_to => ParseRule.init(null, Parser.binary, Precedence.COMPARISON),
        .string => ParseRule.init(Parser.string, null, Precedence.NONE),
        else => ParseRule.init(null, null, Precedence.NONE),
    };
}

pub const Parser = struct {
    const Self = @This();

    current: sc.Token,
    prev: sc.Token,
    scanner: Scanner,
    compiling_chunk: *Chunk,
    had_error: bool,
    panic_mode: bool,
    vm: *VM,

    pub fn init(scanner: Scanner, chunk: *Chunk, vm: *VM) Parser {
        return Parser{
            .current = undefined,
            .prev = undefined,
            .had_error = false,
            .panic_mode = false,
            .scanner = scanner,
            .compiling_chunk = chunk,
            .vm = vm,
        };
    }

    pub fn currentChunk(self: *Self) *Chunk {
        return self.compiling_chunk;
    }

    pub fn advance(self: *Self) void {
        self.prev = self.current;

        while (true) {
            self.current = self.scanner.scanToken();
            if (self.current.type != sc.Tag.error_token) break;

            self.errAtCurrent(self.current.lexeme);
        }
    }

    pub fn expression(self: *Self) void {
        self.parsePrecedence(Precedence.ASSIGNMENT);
    }

    pub fn consume(self: *Self, t_type: sc.Tag, message: []const u8) void {
        if (self.current.type == t_type) {
            self.advance();
            return;
        }

        self.errAtCurrent(message);
    }

    fn grouping(self: *Self) void {
        self.expression();
        self.consume(sc.Tag.rightbracket, "Expected a ')' after the expression.");
    }

    fn number(self: *Self) void {
        const value = std.fmt.parseFloat(f32, self.prev.lexeme) catch unreachable;
        self.emitConstant(Value.makeNumber(value));
    }

    fn string(self: *Self) void {
        const obj_string = self.prev.lexeme[1 .. self.prev.lexeme.len - 1];
        const copied_string = obj.String.copy(self.vm, obj_string);

        self.emitConstant(Value.makeString(copied_string));
    }

    fn unary(self: *Self) void {
        const operatorT = self.prev.type;
        self.parsePrecedence(Precedence.UNARY);

        switch (operatorT) {
            .subtract => self.emitByte(@intFromEnum(chk.OpCode.op_negate)),
            .bang => self.emitByte(@intFromEnum(chk.OpCode.op_not)),
            else => unreachable,
        }
    }

    fn binary(self: *Self) void {
        const operatorT = self.prev.type;
        const rule = getRule(operatorT);

        const precedence: Precedence = @enumFromInt(@intFromEnum(rule.precedence) + 1);
        self.parsePrecedence(precedence);

        switch (operatorT) {
            .plus => self.emitByte(@intFromEnum(chk.OpCode.op_add)),
            .subtract => self.emitByte(@intFromEnum(chk.OpCode.op_subtract)),
            .multiply => self.emitByte(@intFromEnum(chk.OpCode.op_multiply)),
            .divide => self.emitByte(@intFromEnum(chk.OpCode.op_divide)),
            .mod => self.emitByte(@intFromEnum(chk.OpCode.op_mod)),
            .less_than => self.emitByte(@intFromEnum(chk.OpCode.op_less)),
            .greater_than => self.emitByte(@intFromEnum(chk.OpCode.op_greater)),
            .less_than_eql_to => self.emitBytes(@intFromEnum(chk.OpCode.op_less), @intFromEnum(chk.OpCode.op_equal)),
            .greater_than_eql_to => self.emitBytes(@intFromEnum(chk.OpCode.op_greater), @intFromEnum(chk.OpCode.op_equal)),
            .equal_equal => self.emitByte(@intFromEnum(chk.OpCode.op_equal)),
            .bang_equal => self.emitBytes(@intFromEnum(chk.OpCode.op_not), @intFromEnum(chk.OpCode.op_equal)),
            else => unreachable,
        }
    }

    fn literal(self: *Self) void {
        switch (self.prev.type) {
            .keyword_nil => self.emitByte(@intFromEnum(chk.OpCode.op_nil)),
            .keyword_true => self.emitByte(@intFromEnum(chk.OpCode.op_true)),
            .keyword_false => self.emitByte(@intFromEnum(chk.OpCode.op_false)),
            else => unreachable,
        }
    }

    fn parsePrecedence(self: *Self, precedence: Precedence) void {
        self.advance();
        const prefix_rule = getRule(self.prev.type).prefix;

        if (prefix_rule == null) {
            self.err("Expected expression.");
            return;
        }

        prefix_rule.?(self);
        while (@intFromEnum(precedence) <= @intFromEnum(getRule(self.current.type).precedence)) {
            self.advance();
            const infix_rule = getRule(self.prev.type).infix;
            infix_rule.?(self);
        }
    }

    fn emitByte(self: *Self, byte: u8) void {
        self.currentChunk().writeToChunk(byte, self.prev.line);
    }

    fn emitBytes(self: *Self, byte1: u8, byte2: u8) void {
        self.emitByte(byte1);
        self.emitByte(byte2);
    }

    fn emitReturn(self: *Self) void {
        self.emitByte(@intFromEnum(chk.OpCode.op_return));
    }

    fn emitConstant(self: *Self, value: Value) void {
        self.emitBytes(@intFromEnum(chk.OpCode.op_const), self.makeConstant(value));
    }

    fn makeConstant(self: *Self, constant: Value) u8 {
        var chunk = self.currentChunk();
        const constant_idx = chunk.addConstant(constant);

        if (constant_idx > 256) {
            self.err("Too many constants in a single chunk.");
            return 0;
        }

        return constant_idx;
    }

    fn errAtCurrent(self: *Self, message: []const u8) void {
        self.errorAt(&self.current, message);
    }

    fn err(self: *Self, message: []const u8) void {
        self.errorAt(&self.prev, message);
    }

    fn errorAt(self: *Self, token: *sc.Token, message: []const u8) void {
        if (self.panic_mode) return;

        if (token.type == sc.Tag.EOF) {
            Logger.log(std.log.Level.err, .Compiler, "[line {any}] Error at EOF - {s}", .{ token.line, message });
        } else if (token.type == sc.Tag.error_token) {
            Logger.log(std.log.Level.err, .Compiler, "[line {any}] Error - {s}", .{ token.line, message });
        } else {
            Logger.log(std.log.Level.err, .Compiler, "[line {any}] Error at '{s}' - {s}", .{ token.line, token.lexeme, message });
        }

        self.panic_mode = true;
        self.had_error = true;
    }
};
