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
const max_locals = 256;
var compiler: Compiler = undefined;

fn endCompiler(parser: *Parser) void {
    parser.emitReturn();
    if (comptime debug_print_code) {
        if (!parser.had_error) {
            Debug.dissassembleChunk(parser.currentChunk().*, "code");
        }
    }
}

pub fn compile(source: []const u8, vm: *VM, chunk: *Chunk) bool {
    const scanner = Scanner.init(source);
    var parser = Parser.init(scanner, chunk, vm);
    compiler = Compiler.init();

    parser.advance();

    while (!parser.match(sc.Tag.EOF)) {
        parser.declaration();
    }

    endCompiler(&parser);
    return !parser.had_error;
}

pub const Compiler = struct {
    const Self = @This();

    locals: [max_locals]Local,
    local_count: usize,
    scope_depth: i32,

    pub fn init() Compiler {
        return Compiler{
            .locals = undefined,
            .local_count = 0,
            .scope_depth = 0,
        };
    }

    pub fn addLocal(self: *Self, parser: *Parser, name: sc.Token) void {
        if (self.local_count == max_locals) {
            parser.err("Too many variables are in the function/loop.");
            return;
        }
        self.local_count += 1;

        var local = &self.locals[self.local_count];

        local.name = name;
        local.depth = -1;
    }

    pub fn resolveLocal(self: *Self, parser: *Parser, name: *sc.Token) ?usize {
        var idx: usize = compiler.local_count;
        while (idx > 0) : (idx -= 1) {
            const local = self.locals[idx];
            if (std.mem.eql(u8, name.lexeme, local.name.lexeme)) {
                if (local.depth == -1) parser.err("Cannot read a local variable in its own initialiser.");
                return idx - 1;
            }
        }

        return null;
    }

    pub fn markInitialised(self: *Self) void {
        self.locals[self.local_count].depth = self.scope_depth;
    }
};

pub const Local = struct {
    name: sc.Token,
    depth: i32,
};

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

const ParseFn = *const fn (parser: *Parser, can_assign: bool) void;

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
        .identifier => ParseRule.init(Parser.variable, null, Precedence.NONE),
        .keyword_and => ParseRule.init(null, Parser._and, Precedence.AND),
        .keyword_or => ParseRule.init(null, Parser._or, Precedence.OR),
        else => ParseRule.init(null, null, Precedence.NONE),
    };
}

pub const Parser = struct {
    const Self = @This();

    current: sc.Token,
    prev: sc.Token,

    had_error: bool,
    panic_mode: bool,

    vm: *VM,
    scanner: Scanner,
    compiling_chunk: *Chunk,

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

    fn expression(self: *Self) void {
        self.parsePrecedence(Precedence.ASSIGNMENT);
    }

    fn beginScope() void {
        compiler.scope_depth += 1;
    }

    fn endScope(self: *Self) void {
        compiler.scope_depth -= 1;

        while (compiler.local_count > 0 and compiler.locals[compiler.local_count - 1].depth > compiler.scope_depth) {
            self.emitByte(@intFromEnum(chk.OpCode.op_pop));
            compiler.local_count -= 1;
        }
    }

    fn block(self: *Self) void {
        while (!self.checkType(.rightbrace) and !self.checkType(.EOF)) {
            self.declaration();
        }

        self.consume(.rightbrace, "Expected '}' after the block.");
    }

    fn varDeclaration(self: *Self, is_constant: bool) void {
        const global = self.parseVariable("Expected variable identifier.");

        if (self.match(.equal)) {
            self.expression();
        } else {
            self.emitByte(@intFromEnum(chk.OpCode.op_nil));
        }

        self.consume(.semicolon, "Expected ';' after variable declaration.");

        if (is_constant) {
            self.defineConstant(global);
        } else {
            self.defineVariable(global);
        }
    }

    fn exprStatement(self: *Self) void {
        self.expression();
        self.consume(.semicolon, "Expected a ';' after the expression.");
        self.emitByte(@intFromEnum(chk.OpCode.op_pop));
    }

    fn ifStatement(self: *Self) void {
        self.consume(.leftbracket, "Expected a '(' to begin the 'if' condition.");
        self.expression();
        self.consume(.rightbracket, "Expected a ')' to end the 'if' condition.");

        const then_jump = self.emitJump(@intFromEnum(chk.OpCode.op_jump_if_false));
        self.emitByte(@intFromEnum(chk.OpCode.op_pop));
        self.statement();

        const else_jump = self.emitJump(@intFromEnum(chk.OpCode.op_jump));

        self.patchJump(then_jump);
        self.emitByte(@intFromEnum(chk.OpCode.op_pop));

        if (self.match(.keyword_else)) self.statement();
        self.patchJump(else_jump);
    }

    fn printStatement(self: *Self) void {
        self.expression();
        self.consume(.semicolon, "Expected ';' after the value.");
        self.emitByte(@intFromEnum(chk.OpCode.op_print));
    }

    fn whileStatement(self: *Self) void {
        const loop_start = self.currentChunk().code.count;

        self.consume(.leftbracket, "Expected a '(' to begin the condition.");
        self.expression();
        self.consume(.rightbracket, "Expected a ')' to begin the condition.");

        const exit_jump = self.emitJump(@intFromEnum(chk.OpCode.op_jump_if_false));
        self.emitByte(@intFromEnum(chk.OpCode.op_pop));
        self.statement();
        self.emitLoop(loop_start);

        self.patchJump(exit_jump);
        self.emitByte(@intFromEnum(chk.OpCode.op_pop));
    }

    fn forStatement(self: *Self) void {
        beginScope();
        self.consume(.leftbracket, "Expected a '(' to begin a 'for' loop expression.");
        if (self.match(.semicolon)) {
            // No initialier was added.
        } else if (self.match(.keyword_let)) {
            self.varDeclaration(true);
        } else if (self.match(.keyword_letv)) {
            self.varDeclaration(false);
        } else {
            self.exprStatement();
        }

        var loop_start = self.currentChunk().code.count;
        var exit_jump: ?usize = null;
        if (!self.match(.semicolon)) {
            self.expression();
            self.consume(.semicolon, "Expected a ';' to end the loop condition.");

            // A jump out of the loop will occur if the condition is false.
            exit_jump = self.emitJump(@intFromEnum(chk.OpCode.op_jump_if_false));
            self.emitByte(@intFromEnum(chk.OpCode.op_pop));
        }

        if (!self.match(.rightbracket)) {
            const body_jump = self.emitJump(@intFromEnum(chk.OpCode.op_jump));
            const inc_start = self.currentChunk().code.count;
            self.expression();

            self.emitByte(@intFromEnum(chk.OpCode.op_pop));
            self.consume(.rightbracket, "Expected a ')' to end the loop expression.");

            self.emitLoop(loop_start);
            loop_start = inc_start;
            self.patchJump(body_jump);
        }

        self.statement();
        self.emitLoop(loop_start);

        if (exit_jump != null) {
            self.patchJump(exit_jump.?);
            self.emitByte(@intFromEnum(chk.OpCode.op_pop));
        }

        self.endScope();
    }

    fn synchronise(self: *Self) void {
        self.panic_mode = false;

        while (self.current.type == .EOF) {
            if (self.prev.type == .semicolon) return;
            switch (self.current.type) {
                .keyword_struct,
                .keyword_fn,
                .keyword_let,
                .keyword_letv,
                .keyword_if,
                .keyword_while,
                .keyword_for,
                .keyword_print,
                .keyword_return,
                => return,
                else => {},
            }

            self.advance();
        }
    }

    pub fn declaration(self: *Self) void {
        if (self.match(.keyword_letv)) {
            self.varDeclaration(false);
        } else if (self.match(.keyword_let)) {
            self.varDeclaration(true);
        } else {
            self.statement();
        }

        if (self.panic_mode) self.synchronise();
    }

    fn statement(self: *Self) void {
        if (self.match(sc.Tag.keyword_print)) {
            self.printStatement();
        } else if (self.match(sc.Tag.keyword_if)) {
            self.ifStatement();
        } else if (self.match(sc.Tag.leftbrace)) {
            beginScope();
            self.block();
            self.endScope();
        } else if (self.match(sc.Tag.keyword_while)) {
            self.whileStatement();
        } else if (self.match(sc.Tag.keyword_for)) {
            self.forStatement();
        } else {
            self.exprStatement();
        }
    }

    pub fn match(self: *Self, t_type: sc.Tag) bool {
        if (!self.checkType(t_type)) return false;

        self.advance();
        return true;
    }

    fn checkType(self: *Self, t_type: sc.Tag) bool {
        return self.current.type == t_type;
    }

    pub fn consume(self: *Self, t_type: sc.Tag, message: []const u8) void {
        if (self.current.type == t_type) {
            self.advance();
            return;
        }

        self.errAtCurrent(message);
    }

    fn grouping(self: *Self, can_assign: bool) void {
        _ = can_assign;
        self.expression();
        self.consume(sc.Tag.rightbracket, "Expected a ')' after the expression.");
    }

    fn number(self: *Self, can_assign: bool) void {
        _ = can_assign;
        const value = std.fmt.parseFloat(f32, self.prev.lexeme) catch unreachable;
        self.emitConstant(Value.makeNumber(value));
    }

    fn string(self: *Self, can_assign: bool) void {
        _ = can_assign;
        const obj_string = self.prev.lexeme[1 .. self.prev.lexeme.len - 1];
        const copied_string = obj.String.copy(self.vm, obj_string);

        self.emitConstant(Value.makeString(copied_string));
    }

    fn variable(self: *Self, can_assign: bool) void {
        self.namedVariable(&self.prev, can_assign);
    }

    fn namedVariable(self: *Self, name: *sc.Token, can_assign: bool) void {
        var getOp: chk.OpCode = undefined;
        var setOp: chk.OpCode = undefined;
        var arg = compiler.resolveLocal(self, name);

        if (arg != null) {
            getOp = chk.OpCode.op_get_local;
            setOp = chk.OpCode.op_set_local;
        } else {
            arg = self.constIdentifier(name);
            getOp = chk.OpCode.op_get_global;
            setOp = chk.OpCode.op_set_global;
        }

        if (self.match(.equal) and can_assign) {
            self.expression();
            self.emitBytes(@intFromEnum(setOp), @intCast(arg.?));
        } else {
            self.emitBytes(@intFromEnum(getOp), @intCast(arg.?));
        }
    }

    fn unary(self: *Self, can_assign: bool) void {
        _ = can_assign;
        const operatorT = self.prev.type;
        self.parsePrecedence(Precedence.UNARY);

        switch (operatorT) {
            .subtract => self.emitByte(@intFromEnum(chk.OpCode.op_negate)),
            .bang => self.emitByte(@intFromEnum(chk.OpCode.op_not)),
            else => unreachable,
        }
    }

    fn binary(self: *Self, can_assign: bool) void {
        _ = can_assign;
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

    fn literal(self: *Self, can_assign: bool) void {
        _ = can_assign;
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

        const can_assign = @intFromEnum(precedence) <= @intFromEnum(Precedence.ASSIGNMENT);
        prefix_rule.?(self, can_assign);

        while (@intFromEnum(precedence) <= @intFromEnum(getRule(self.current.type).precedence)) {
            self.advance();
            const infix_rule = getRule(self.prev.type).infix;
            infix_rule.?(self, can_assign);
        }

        if (can_assign and self.match(.equal)) {
            self.err("Invalid assignment target.");
        }
    }

    fn constIdentifier(self: *Self, name: *sc.Token) u8 {
        return self.makeConstant(Value.makeString(obj.String.copy(self.vm, name.lexeme)));
    }

    fn declareVariable(self: *Self) void {
        if (compiler.scope_depth == 0) return;
        var idx: usize = compiler.local_count;

        const name = self.prev;
        while (idx > 0) {
            idx -= 1;

            const local = compiler.locals[idx];
            if (local.depth != -1 and local.depth < compiler.scope_depth) {
                break;
            }

            if (std.mem.eql(u8, name.lexeme, local.name.lexeme)) {
                self.err("Cannot redeclare a variable within the same scope.");
            }
        }

        compiler.addLocal(self, name);
    }

    fn parseVariable(self: *Self, err_message: []const u8) u8 {
        self.consume(.identifier, err_message);

        self.declareVariable();
        if (compiler.scope_depth > 0) return 0;

        return self.constIdentifier(&self.prev);
    }

    fn defineVariable(self: *Self, global_idx: u8) void {
        if (compiler.scope_depth > 0) {
            compiler.markInitialised();
            return;
        }

        self.emitBytes(@intFromEnum(chk.OpCode.op_defvar_global), global_idx);
    }

    fn _and(self: *Self, can_assign: bool) void {
        _ = can_assign;

        const end_jump = self.emitJump(@intFromEnum(chk.OpCode.op_jump_if_false));
        self.emitByte(@intFromEnum(chk.OpCode.op_pop));
        self.parsePrecedence(.AND);

        self.patchJump(end_jump);
    }

    fn _or(self: *Self, can_assign: bool) void {
        _ = can_assign;

        const else_jump = self.emitJump(@intFromEnum(chk.OpCode.op_jump_if_false));
        const end_jump = self.emitJump(@intFromEnum(chk.OpCode.op_jump));

        self.patchJump(else_jump);
        self.emitByte(@intFromEnum(chk.OpCode.op_pop));

        self.parsePrecedence(.OR);
        self.patchJump(end_jump);
    }

    fn defineConstant(self: *Self, global_idx: u8) void {
        if (compiler.scope_depth > 0) {
            compiler.markInitialised();
            return;
        }

        self.emitBytes(@intFromEnum(chk.OpCode.op_defconst_global), global_idx);
    }

    fn emitByte(self: *Self, byte: u8) void {
        self.currentChunk().writeToChunk(byte, self.prev.line);
    }

    fn emitBytes(self: *Self, byte1: u8, byte2: u8) void {
        self.emitByte(byte1);
        self.emitByte(byte2);
    }

    fn emitLoop(self: *Self, loop_start: usize) void {
        self.emitByte(@intFromEnum(chk.OpCode.op_loop));
        const offset = self.currentChunk().code.count - loop_start + 2;

        if (offset > std.math.maxInt(u16)) self.err("The loop body is too large.");

        const op1: u8 = @truncate(offset >> 8);
        const op2: u8 = @truncate(offset);

        self.emitBytes(op1 & 0xff, op2 & 0xff);
    }

    fn emitJump(self: *Self, instruction: u8) usize {
        self.emitByte(instruction);
        self.emitBytes(0xff, 0xff);

        return self.currentChunk().code.count - 2;
    }

    fn emitReturn(self: *Self) void {
        self.emitByte(@intFromEnum(chk.OpCode.op_return));
    }

    fn emitConstant(self: *Self, value: Value) void {
        self.emitBytes(@intFromEnum(chk.OpCode.op_const), self.makeConstant(value));
    }

    fn patchJump(self: *Self, offset: usize) void {
        // -2 adjusts for the bytecode of the jump itself.
        const jump = self.currentChunk().code.count - offset - 2;

        if (jump > std.math.maxInt(u16)) self.err("Cannot jump over that much code.");

        const op1: u8 = @truncate(jump >> 8);
        const op2: u8 = @truncate(jump);

        self.currentChunk().code.items[offset] = op1 & 0xff;
        self.currentChunk().code.items[offset + 1] = op2 & 0xff;
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
            Logger.log(std.log.Level.err, .Compiler, null, "[line {any}] Error at EOF - {s}", .{ token.line, message });
        } else if (token.type == sc.Tag.error_token) {
            Logger.log(std.log.Level.err, .Compiler, null, "[line {any}] Error - {s}", .{ token.line, message });
        } else {
            Logger.log(std.log.Level.err, .Compiler, null, "[line {any}] Error at '{s}' - {s}", .{ token.line, token.lexeme, message });
        }

        self.panic_mode = true;
        self.had_error = true;
    }
};
