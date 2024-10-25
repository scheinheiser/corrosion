const std = @import("std");
const log = @import("../logger.zig");

const Logger = log.Logger;

pub const Value = union(enum) {
    const Self = @This();

    boolean: bool,
    nil,
    number: f32,

    pub fn makeBool(value: bool) Value {
        return Value{ .boolean = value };
    }

    pub fn makeNil() Value {
        return Value.nil;
    }

    pub fn makeNumber(value: f32) Value {
        return Value{ .number = value };
    }

    pub fn isBool(self: *Self) bool {
        return self.* == .boolean;
    }

    pub fn isNil(self: *Self) bool {
        return self.* == .nil;
    }

    pub fn isNum(self: *Self) bool {
        return self.* == .number;
    }

    pub fn asBool(self: *Self) bool {
        std.debug.assert(self.isBool());
        return self.boolean;
    }

    pub fn asNumber(self: *Self) f32 {
        std.debug.assert(self.isNum());
        return self.number;
    }

    pub fn printValue(self: *Self) void {
        switch (self.*) {
            .number => std.debug.print("'{d:.3}'\n", .{self.*.number}),
            .boolean => std.debug.print("'{any}'\n", .{self.*.boolean}),
            .nil => std.debug.print("'nil'\n", .{}),
        }
    }

    pub fn logValue(self: *Self) void {
        switch (self.*) {
            .number => Logger.log(std.log.Level.debug, .Result, "{d:.3}", .{self.*.number}),
            .boolean => Logger.log(std.log.Level.debug, .Result, "{any}", .{self.*.boolean}),
            .nil => Logger.log(std.log.Level.debug, .Result, "nil", .{}),
        }
    }
};
