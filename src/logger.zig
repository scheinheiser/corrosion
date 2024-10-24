const std = @import("std");

pub const LogLevel = enum {
    Debug,
    Info,
    Warn,
    Err,
};

pub const Logger = struct {
    const Self = @This();

    pub fn log(
        comptime level: LogLevel,
        comptime scope: anytype,
        comptime text: []const u8,
        args: anytype,
    ) void {
        const formatted_message: []u8 = undefined;
        _ = std.fmt.bufPrint(formatted_message, text, args) catch {};

        switch (level) {
            .Debug => std.log.scoped(scope).debug("{s}", .{formatted_message}),
            .Info => std.log.scoped(scope).info("{s}", .{formatted_message}),
            .Warn => std.log.scoped(scope).warn("{s}", .{formatted_message}),
            .Err => std.log.scoped(scope).err("{s}", .{formatted_message}),
        }
    }
};
