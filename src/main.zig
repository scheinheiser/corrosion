const std = @import("std");
const chk = @import("chunk.zig");
const debug = @import("debug.zig");
const virtual_machine = @import("vm.zig");

const Chunk = chk.Chunk;
const Opcode = chk.OpCode;
const VM = virtual_machine.VirtualMachine;

pub fn main() void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var virtual = VM.initVM();
    virtual.deinitVM();

    switch (args.len) {
        1 => repl(&virtual),
        2 => runFile(args[1], &virtual),
        else => {
            std.debug.print("Usage: buzz [path]\n", .{});
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

fn runFile(path: []const u8, vm: *VM) void {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(vm.allocator, std.math.maxInt(u32));
    const res = vm.interpret(source);

    switch (res) {
        .COMPILE_ERROR => std.process.exit(65),
        .RUNTIME_ERROR => std.process.exit(70),
    }
}
