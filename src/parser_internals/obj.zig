const std = @import("std");
const Value = @import("value.zig").Value;
const log = @import("../logger.zig");
const VirtualMachine = @import("vm.zig");
const tbl = @import("table.zig");

const Logger = log.Logger;
const VM = VirtualMachine.VirtualMachine;
const Table = tbl.Table;

pub const ObjType = enum {
    String,
};

pub const Obj = struct {
    const Self = @This();

    type: ObjType,
    next: ?*Obj,

    pub fn make(vm: *VM, comptime T: type, obj_type: ObjType) *T {
        var obj_pointer = vm.allocator.create(T) catch {
            Logger.log(std.log.Level.err, .Obj, @src(), "Failed to create object.", .{});
            std.process.exit(1);
        };

        obj_pointer.obj = Obj{
            .type = obj_type,
            .next = vm.objects,
        };

        vm.objects = &obj_pointer.obj;

        return obj_pointer;
    }

    pub fn isType(self: Self, obj_type: ObjType) bool {
        return self.type == obj_type;
    }
};

pub const String = struct {
    const Self = @This();

    obj: Obj,
    characters: []const u8,
    hash: u32,

    fn allocate(vm: *VM, characters: []const u8, hash: u32) *String {
        const str = Obj.make(vm, @This(), .String);
        str.characters = characters;
        str.hash = hash;

        _ = vm.strings.setValue(str, .nil, true) catch unreachable;
        return str;
    }

    pub fn copy(vm: *VM, characters: []const u8) *String {
        const hash = hashString(characters);
        const interned_string = vm.strings.findString(characters, hash);
        if (interned_string != null) return interned_string.?;

        const heap_bytes = vm.allocator.alloc(u8, characters.len) catch {
            Logger.log(std.log.Level.err, .Obj, @src(), "Failed to copy string.", .{});
            std.process.exit(1);
        };

        std.mem.copyForwards(u8, heap_bytes, characters);
        return allocate(vm, heap_bytes, hash);
    }

    pub fn takeString(vm: *VM, characters: []const u8) *String {
        const hash = hashString(characters);
        const interned_string = vm.strings.findString(characters, hash);
        if (interned_string != null) {
            vm.allocator.free(characters);
            return interned_string.?;
        }

        return allocate(vm, characters, hash);
    }

    pub fn hashString(characters: []const u8) u32 {
        var hash: u32 = 2166136261;
        for (characters) |char| {
            hash ^= char;
            hash *%= 16777619;
        }

        return hash;
    }

    pub fn deinit(object: *Obj, vm: *VM) void {
        const self: *String = @fieldParentPtr("obj", object);
        vm.allocator.free(self.characters);
        vm.allocator.destroy(self);
    }
};
