const std = @import("std");
const sc = @import("scanner.zig");
const chk = @import("chunk.zig");

const Scanner = sc.Scanner;
const Chunk = chk.Chunk;

var compiling_chunk = undefined;

inline fn currentChunk() Chunk {
    return compiling_chunk.*;
}

fn endCompiler(parser: *Parser) void {
    parser.*.emitReturn();
}

pub fn compile(source: [:0]const u8, chunk: *Chunk) bool {
    const scanner = Scanner.init(source);
    const parser = Parser.init();
    compiling_chunk = chunk;

    parser.advance(scanner);
    expression();
    parser.consume(sc.Tag.EOF, "Expect end of expression.");

    endCompiler(&parser);
    return !parser.had_error;
}

pub const Parser = struct {
    const Self = @This();

    current: sc.Token,
    prev: sc.Token,
    had_error: bool,
    panic_mode: bool,

    pub fn init() Parser {
        return Parser{
            .current = undefined,
            .prev = undefined,
            .had_error = false,
            .panic_mode = false,
        };
    }

    pub fn advance(self: *Self, scanner: Scanner) void {
        self.prev = self.current;

        while (true) {
            self.current = scanner.scanToken();
            if (self.current.type != sc.Tag.error_token) break;

            self.errorCallAtCurrent();
        }
    }

    pub fn consume(self: *Self, t_type: sc.Tag, message: []const u8) void {
        if (self.current.type == t_type) {
            self.advance;
            return;
        }

        self.errorCallAtCurrent(message);
    }

    fn emitByte(self: *Self, byte: u8) void {
        const current_chunk = currentChunk();
        current_chunk.writeChunk(byte, self.prev.line);
    }

    fn emitBytes(self: *Self, byte1: u8, byte2: u8) void {
        self.emitByte(byte1);
        self.emitByte(byte2);
    }

    fn emitReturn(self: *Self) void {
        self.emitByte(chk.OpCode.op_return);
    }

    fn errorCallAtCurrent(self: *Self, message: []const u8) void {
        self.errorAt(&self.current, message);
    }

    fn errorCall(self: *Self, message: []const u8) void {
        self.errorAt(&self.prev, message);
    }

    fn errorAt(self: *Self, token: *sc.Token, message: []const u8) void {
        if (self.panic_mode) return;
        std.log.info("[line {any}] Error", .{token.line});

        if (token.type == sc.Tag.EOF) {
            std.log.info(" at EOF", .{});
        } else if (token.type == sc.Tag.error_token) {
            // empty branch baybee
        } else {
            std.log.info(" at {s}", .{token.lexeme});
        }

        std.log.info(": {s}\n", .{message});
        self.panic_mode = true;
        self.had_error = true;
    }
};
