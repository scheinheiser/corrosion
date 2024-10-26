const std = @import("std");

pub const Logger = struct {
    pub fn log(
        comptime level: std.log.Level,
        comptime scope: anytype,
        comptime text: []const u8,
        args: anytype,
    ) void {
        const scope_prefix = "(" ++ comptime @tagName(scope) ++ "): ";
        const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.io.getStdErr().writer();
        stderr.print(prefix ++ text ++ "\n", args) catch return;
    }
};
