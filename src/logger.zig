const std = @import("std");

pub const Logger = struct {
    pub fn log(
        comptime level: std.log.Level,
        comptime scope: anytype,
        comptime src: ?std.builtin.SourceLocation,
        comptime text: []const u8,
        args: anytype,
    ) void {
        const scope_prefix = "(" ++ comptime @tagName(scope) ++ ")";
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.io.getStdErr().writer();

        if (src != null) {
            const src_prefix = " ~ @" ++ src.?.file ++ "; " ++ src.?.fn_name ++ "(): ";
            const prefix = "[" ++ comptime level.asText() ++ "] ~ " ++ scope_prefix ++ src_prefix;

            stderr.print(prefix ++ text ++ "\n", args) catch return;
        } else {
            const prefix = "[" ++ comptime level.asText() ++ "] ~ " ++ scope_prefix ++ ": ";
            stderr.print(prefix ++ text ++ "\n", args) catch return;
        }
    }
};
