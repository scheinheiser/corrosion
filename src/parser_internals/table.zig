const std = @import("std");
const obj = @import("obj.zig");
const val = @import("value.zig");
const log = @import("../logger.zig");

const ObjString = obj.String;
const Value = val.Value;
const Logger = log.Logger;

const table_max_load: f32 = 0.75;

pub const Entry = struct {
    key: ?*ObjString = null,
    value: Value = .nil,
};

pub const Table = struct {
    const Self = @This();

    count: usize,
    capacity: usize,
    entries: []Entry,
    allocator: std.mem.Allocator,

    pub fn init() Table {
        return Table{
            .count = 0,
            .capacity = 0,
            .entries = &[_]Entry{},
            .allocator = std.heap.page_allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.entries);

        self.count = 0;
        self.capacity = 0;
    }

    pub fn setValue(self: *Self, key: *ObjString, value: Value) bool {
        const capacity: f32 = @floatFromInt(self.capacity);
        const count: f32 = @floatFromInt(self.count);

        if (count + 1 > capacity * table_max_load) {
            self.capacity = if (self.capacity < 8) 8 else self.capacity * 2;
            self.adjustCapacity();
        }

        const entry = findEntry(self.entries, key);
        const is_new_key = entry.key == null;
        if (is_new_key and entry.value.isNil()) self.count += 1;

        entry.key = key;
        entry.value = value;
        return is_new_key;
    }

    pub fn deleteValue(self: *Self, key: *ObjString) bool {
        if (self.count == 0) return false;

        const entry = findEntry(self.entries, key);
        if (entry.key == null) return false;

        entry.key = null;
        entry.value = .{ .boolean = true };
        return true;
    }

    pub fn setAll(old: *Self, new: *Table) void {
        for (old.entries) |*entry| {
            if (entry.key != null) {
                new.setValue(entry.key.?, entry.value);
            }
        }
    }

    fn findEntry(entries: []Entry, key: *ObjString) *Entry {
        var index = key.hash % entries.len;
        var tombstone: ?*Entry = null;

        while (true) {
            const entry = &entries[index];
            if (entry.key == null) {
                if (entry.value.isNil()) {
                    return tombstone orelse entry;
                } else {
                    if (tombstone == null) tombstone = entry;
                }
            } else if (entry.key == key) {
                return entry;
            }

            index = (index + 1) % entries.len;
        }
    }

    pub fn findString(self: *Self, characters: []const u8, hash: u32) ?*ObjString {
        if (self.count == 0) return null;

        var index = hash % self.entries.len;
        while (true) {
            const entry = &self.entries[index];
            if (entry.key == null) {
                if (entry.value.isNil()) return null;
            } else if (entry.key.?.hash == hash and std.mem.eql(u8, entry.key.?.characters, characters)) {
                return entry.key.?;
            }

            index = (index + 1) % self.entries.len;
        }
    }

    fn getValue(self: *Self, key: *ObjString) Value {
        if (self.count == 0) return .nil;

        const entry = findEntry(self.entries, key);
        if (entry.key == null) return .nil;

        return entry.value;
    }

    fn adjustCapacity(self: *Self) void {
        const entries = self.allocator.alloc(Entry, self.capacity) catch {
            Logger.log(std.log.Level.err, .HashTbl, "Ran out of memory to increase the size of the hash table.", .{});
            std.process.exit(1);
        };

        for (entries) |*entry| {
            entry.* = Entry{};
        }

        self.count = 0;
        for (self.entries) |*entry| {
            if (entry.key == null) continue;

            const new_entry = findEntry(entries, entry.key.?);
            new_entry.key = entry.key;
            new_entry.value = entry.value;

            self.count += 1;
        }

        self.allocator.free(self.entries);
        self.entries = entries;
    }
};
