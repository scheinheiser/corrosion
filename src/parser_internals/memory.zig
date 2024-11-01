const std = @import("std");
const log = @import("../logger.zig");

const Logger = log.Logger;

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

        pub fn growCapacity(self: *Self) void {
            if (self.capacity < 8) {
                self.capacity = 8;
            } else {
                self.capacity *= 2;
            }
        }

        pub fn growArray(self: *Self, new_capacity: usize) void {
            return self.reallocate(@sizeOf([]T) * new_capacity);
        }

        pub fn freeArray(self: *Self) void {
            return self.reallocate(0);
        }

        fn reallocate(self: *Self, new_size: usize) void {
            if (new_size == 0) {
                self.allocator.free(self.items);
                return;
            }

            const result = self.allocator.realloc(self.items, new_size) catch {
                Logger.log(std.log.Level.err, .Memory, @src(), "Ran out of memory to increase the size of the array.", .{});
                std.process.exit(1);
            };

            self.items = result;
        }
    };
}
