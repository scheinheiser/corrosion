const std = @import("std");
const sc = @import("scanner.zig");

const Scanner = sc.Scanner;

pub fn compile(source: [:0]const u8) void {
    const scanner = Scanner.init(source);
    var line = -1;
    while (true) {
        const token = scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{any} ", .{token.line});
            line = token.line;
        } else {
            std.debug.print("    | ", .{});
        }

        std.debug.print("{d} '{s}'\n", .{ token.type, token.start[token.length] });
        if (token.type == .EOF) break;
    }
}
