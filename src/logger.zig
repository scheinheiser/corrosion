const std = @import("std");

pub const Logger = struct {
    pub fn log(
        comptime level: std.log.Level,
        comptime scope: anytype,
        comptime text: []const u8,
        args: anytype,
    ) void {
        switch (level) {
            .debug => std.log.scoped(scope).debug(text, args),
            .info => std.log.scoped(scope).info(text, args),
            .warn => std.log.scoped(scope).warn(text, args),
            .err => std.log.scoped(scope).err(text, args),
        }
    }
};
