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
        comptime format: []const u8,
        args: anytype,
    ) void {
        const formatted_message = std.fmt.format(format, args) catch {};

        switch (level) {
            .Debug => std.log.scoped(scope).debug("{}", .{formatted_message}),
            .Info => std.log.scoped(scope).info("{}", .{formatted_message}),
            .Warn => std.log.scoped(scope).warn("{}", .{formatted_message}),
            .Err => std.log.scoped(scope).err("{}", .{formatted_message}),
        }
    }
};
