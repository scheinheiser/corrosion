const std = @import("std");
const Value = @import("value.zig").Value;
const log = @import("../logger.zig");
const VirtualMachine = @import("vm.zig");

const Logger = log.Logger;
const VM = VirtualMachine.VirtualMachine;

pub const ObjType = enum {
    String,
};

pub const Obj = struct {
    const Self = @This();

    type: ObjType,
    next: ?*Obj,

    pub fn make(vm: *VM, comptime T: type, obj_type: ObjType) *T {
        var obj_pointer = vm.allocator.create(T) catch {
            Logger.log(std.log.Level.err, .Obj, "Failed to create object.", .{});
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

    fn allocate(vm: *VM, characters: []const u8) *String {
        const str = Obj.make(vm, @This(), .String);
        str.characters = characters;
        return str;
    }

    pub fn copy(vm: *VM, characters: []const u8) *String {
        const heap_bytes = vm.allocator.alloc(u8, characters.len) catch {
            Logger.log(std.log.Level.err, .Obj, "Failed to copy string.", .{});
            std.process.exit(1);
        };

        std.mem.copyForwards(u8, heap_bytes, characters);
        return allocate(vm, heap_bytes);
    }

    pub fn deinit(object: *Obj, vm: *VM) void {
        const self: *String = @fieldParentPtr("obj", object);
        vm.allocator.free(self.characters);
        vm.allocator.destroy(self);
    }
};
