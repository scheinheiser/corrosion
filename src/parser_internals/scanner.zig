const std = @import("std");
const Log = @import("../logger.zig");

const Logger = Log.Logger;

pub const Tag = enum {
    // Single character tokens
    leftbracket, // (
    rightbracket, // )
    double_quote, // " .. "
    single_quote, // ' .. '
    plus, // +
    subtract, // -
    multiply, // *
    divide, // /
    dot, // .
    comma, // ,
    bang, // !
    greater_than, // >
    less_than, // <

    // Double character tokens
    bang_equal, // !=
    equal_equal, // ==
    less_than_eql_to, // <=
    greater_than_eql_to, // >=

    // Keywords
    keyword_print,
    keyword_defvar,
    keyword_defconstant,
    keyword_set,
    keyword_setq,
    keyword_setf,
    keyword_write,
    keyword_writeline,
    keyword_return,
    keyword_fn,
    keyword_and,
    keyword_or,
    keyword_nil,
    keyword_if,
    keyword_false,
    keyword_true,

    // Literals
    string,
    integer,
    float,

    // Misc
    identifier,
    comment,

    // Other
    error_token,
    EOF,
    whitespace,
    linebreak,
};

pub const Token = struct {
    const Self = @This();

    type: Tag,
    lexeme: []const u8,
    length: usize,
    line: i32,
};

pub const Scanner = struct {
    const Self = @This();

    source: []const u8,
    start: usize,
    current: usize,
    line: i32,

    pub fn init(source: []const u8) Scanner {
        return Scanner{
            .start = 0,
            .current = 0,
            .source = source,
            .line = 1,
        };
    }

    fn isDigit(character: u8) bool {
        return '0' <= character and '9' >= character;
    }

    fn isAlpha(character: u8) bool {
        return (character >= 'a' and character <= 'z') or (character >= 'A' and character <= 'Z') or character == '_';
    }

    pub fn scanToken(self: *Self) Token {
        self.skipWhitespace();
        self.start = self.current;
        if (self.isAtEnd()) return self.makeToken(Tag.EOF);

        const character = self.advance();
        if (isAlpha(character)) return self.identifier();
        if (isDigit(character)) return self.number();

        switch (character) {
            '(' => return self.makeToken(Tag.leftbracket),
            ')' => return self.makeToken(Tag.rightbracket),
            ',' => return self.makeToken(Tag.comma),
            '.' => return self.makeToken(Tag.dot),
            '+' => return self.makeToken(Tag.plus),
            '-' => return self.makeToken(Tag.subtract),
            '*' => return self.makeToken(Tag.multiply),
            '/' => return self.makeToken(Tag.divide),
            '!' => return self.makeToken(if (self.match('=') == true) Tag.bang_equal else Tag.bang),
            '=' => {
                if (self.match('=') == true) {
                    return self.makeToken(Tag.equal_equal);
                } else {
                    return self.errorToken("Single '='.");
                }
            },
            '>' => return self.makeToken(if (self.match('=') == true) Tag.greater_than_eql_to else Tag.greater_than),
            '<' => return self.makeToken(if (self.match('=') == true) Tag.less_than_eql_to else Tag.less_than),
            '"' => return self.string(),
            else => return self.errorToken("Unexpected character."),
        }
    }

    fn advance(self: *Self) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn match(self: *Self, expected_char: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected_char) return false;

        self.current += 1;
        return true;
    }

    fn skipWhitespace(self: *Self) void {
        while (true) {
            const char = self.peek();
            switch (char) {
                ' ', '\r', '\t' => _ = self.advance(),
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                ';' => {
                    while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                },
                else => break,
            }
        }
    }

    fn identifierType(self: *Self) Tag {
        switch (self.source[self.start]) {
            'p' => return self.checkKeyword("print", Tag.keyword_print),
            'd' => switch (self.source[self.start + 3]) {
                'v' => return self.checkKeyword("defvar", Tag.keyword_defvar),
                'c' => return self.checkKeyword("defconstant", Tag.keyword_defconstant),
                else => return Tag.identifier,
            },
            's' => {
                if (!isAlpha(self.source[self.start + 3])) {
                    return self.checkKeyword("set", Tag.keyword_set);
                } else {
                    switch (self.source[self.start + 3]) {
                        'q' => return self.checkKeyword("setq", Tag.keyword_setq),
                        'f' => return self.checkKeyword("setf", Tag.keyword_setf),
                        else => return Tag.identifier,
                    }
                }
            },
            'w' => {
                if (!isAlpha(self.source[self.start + 5])) {
                    return self.checkKeyword("write", Tag.keyword_write);
                } else {
                    return self.checkKeyword("writeline", Tag.keyword_writeline);
                }
            },
            'r' => return self.checkKeyword("return", Tag.keyword_return),
            'f' => switch (self.source[self.start + 1]) {
                'n' => return self.checkKeyword("fn", Tag.keyword_fn),
                'a' => return self.checkKeyword("false", Tag.keyword_false),
                else => return Tag.identifier,
            },
            'a' => return self.checkKeyword("and", Tag.keyword_and),
            'o' => return self.checkKeyword("or", Tag.keyword_or),
            'n' => return self.checkKeyword("nil", Tag.keyword_nil),
            'i' => return self.checkKeyword("if", Tag.keyword_if),
            't' => return self.checkKeyword("true", Tag.keyword_true),
            else => return Tag.identifier,
        }
    }

    fn checkKeyword(self: *Self, keyword: []const u8, keyword_type: Tag) Tag {
        if (std.mem.eql(u8, self.source[self.start..self.current], keyword)) {
            return keyword_type;
        }

        return Tag.identifier;
    }

    fn number(self: *Self) Token {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance();

            while (isDigit(self.peek())) _ = self.advance();

            return self.makeToken(Tag.float);
        } else if (self.peek() == '.') {
            return self.errorToken("Unexpected character.");
        }

        return self.makeToken(Tag.integer);
    }

    fn identifier(self: *Self) Token {
        while (isAlpha(self.peek()) or isDigit(self.peek())) _ = self.advance();

        return self.makeToken(self.identifierType());
    }

    // TODO: stop multiline strings from being the default string syntax.
    fn string(self: *Self) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) return self.errorToken("Unterminated string.");

        _ = self.advance();
        return self.makeToken(Tag.string);
    }

    fn peek(self: *Self) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *Self) u8 {
        return self.source[self.current + 1];
    }

    fn isAtEnd(self: *Self) bool {
        return self.current >= self.source.len;
    }

    fn makeToken(self: *Self, token_tag: Tag) Token {
        return Token{
            .type = token_tag,
            .line = self.line,
            .lexeme = self.source[self.start..self.current],
            .length = self.current - self.start,
        };
    }

    fn errorToken(self: *Self, error_message: []const u8) Token {
        return Token{
            .type = Tag.error_token,
            .line = self.line,
            .lexeme = error_message,
            .length = error_message.len,
        };
    }
};
