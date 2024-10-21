const std = @import("std");

pub fn DynArray(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        count: usize,
        capacity: usize,
        allocator: std.mem.Allocator,

        pub fn initArr() Self {
            return Self{
                .capacity = 0,
                .count = 0,
                .items = &[_]T{},
                .allocator = std.heap.page_allocator,
            };
        }

        pub fn growCapacity(self: *Self) usize {
            if (self.capacity < 8) {
                return 8;
            } else {
                return self.capacity * 2;
            }
        }

        pub fn growArray(self: *Self, new_capacity: usize) void {
            return self.reallocate(@sizeOf([]T) * new_capacity);
        }

        pub fn freeArray(self: *Self) void {
            return self.reallocate(0);
        }

        pub fn reallocate(self: *Self, new_size: usize) void {
            if (new_size == 0) {
                self.allocator.free(self.items);
                return;
            }

            const result = self.allocator.realloc(self.items, new_size) catch |err| {
                std.debug.print("Something something error -> {any}\n", .{err});
                std.posix.exit(1);
            };

            self.items = result;
        }
    };
}
