const std = @import("std");
const chk = @import("parser_internals/chunk.zig");
const virtual_machine = @import("parser_internals/vm.zig");
const Log = @import("logger.zig");

const Chunk = chk.Chunk;
const Opcode = chk.OpCode;
const VM = virtual_machine.VirtualMachine;
const Logger = Log.Logger;
const LogLevel = Log.LogLevel;

pub const std_options = struct {
    pub const log_level = .debug;

    pub const log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .VM, .level = log_level },
        .{ .scope = .Compiler, .level = log_level },
        .{ .scope = .Chunk, .level = log_level },
        .{ .scope = .Memory, .level = log_level },
        .{ .scope = .Scanner, .level = log_level },
        .{ .scope = .Debug, .level = log_level },
        .{ .scope = .REPL, .level = log_level },
    };
};

pub fn main() void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var virtual = VM.initVM();
    virtual.deinitVM();

    switch (args.len) {
        1 => repl(&virtual),
        2 => runFile(args[1], &virtual, allocator),
        else => {
            Logger.log(LogLevel.Err, .REPL, "Usage: buzz [path]\n", .{});
            std.process.exit(64);
        },
    }
}

fn repl(vm: *VM) !void {
    const std_in = std.io.getStdIn();

    var buf = std.io.bufferedReader(std_in.reader());
    var reader = buf.reader();
    const line_buf: [1024:0]u8 = undefined;

    while (true) {
        std.debug.print("> ", .{});
        const line = (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) orelse {
            std.debug.print("\n", .{});
            break;
        };

        vm.interpret(line);
    }
}

fn runFile(path: []const u8, vm: *VM, allocator: std.mem.allocator) void {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    const res = vm.interpret(source);

    switch (res) {
        .COMPILE_ERROR => std.process.exit(65),
        .RUNTIME_ERROR => std.process.exit(70),
    }
}
