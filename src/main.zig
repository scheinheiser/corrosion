const std = @import("std");
const chk = @import("parser_internals/chunk.zig");
const virtual_machine = @import("parser_internals/vm.zig");
const Log = @import("logger.zig");

const Chunk = chk.Chunk;
const Opcode = chk.OpCode;
const VM = virtual_machine.VirtualMachine;
const Logger = Log.Logger;

pub const std_options: std.Options = std.Options{
    .log_level = .info,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .VM, .level = .debug },
        .{ .scope = .Compiler, .level = .debug },
        .{ .scope = .Chunk, .level = .debug },
        .{ .scope = .Memory, .level = .debug },
        .{ .scope = .Scanner, .level = .debug },
        .{ .scope = .Debug, .level = .debug },
        .{ .scope = .Result, .level = .debug },
        .{ .scope = .REPL, .level = .debug },
        .{ .scope = .HashTbl, .level = .debug },
    },
};

pub fn main() !void {
    //TODO: Change to a gpa.
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var virtual = VM.initVM();

    try switch (args.len) {
        1 => repl(&virtual),
        2 => try runFile(args[1], &virtual, allocator),
        else => {
            Logger.log(std.log.Level.err, .REPL, null, "Usage: buzz [path]\n", .{});
            std.process.exit(64);
        },
    };
}

fn repl(vm: *VM) !void {
    const std_in = std.io.getStdIn();

    var buf = std.io.bufferedReader(std_in.reader());
    var reader = buf.reader();
    var line_buf: [1024]u8 = undefined;

    while (true) {
        std.debug.print("> ", .{});
        const line = (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) orelse {
            std.debug.print("\n", .{});
            break;
        };

        _ = vm.interpret(line);
    }

    vm.deinitVM();
}

fn runFile(path: []const u8, vm: *VM, allocator: std.mem.Allocator) !void {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    const res = vm.interpret(source);

    vm.deinitVM();
    switch (res) {
        .OK => {},
        .COMPILE_ERROR => std.process.exit(65),
        .RUNTIME_ERROR => std.process.exit(70),
    }
}
