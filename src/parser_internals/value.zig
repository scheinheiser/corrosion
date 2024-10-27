const std = @import("std");
const log = @import("../logger.zig");
const obj = @import("obj.zig");

const Logger = log.Logger;
const Obj = obj.Obj;
const ObjType = obj.ObjType;

pub const Value = union(enum) {
    const Self = @This();

    boolean: bool,
    nil,
    number: f32,
    string: *obj.String,

    pub fn makeBool(value: bool) Value {
        return Value{ .boolean = value };
    }

    pub fn makeNil() Value {
        return Value.nil;
    }

    pub fn makeNumber(value: f32) Value {
        return Value{ .number = value };
    }

    pub fn makeString(value: *obj.String) Value {
        return Value{ .string = value };
    }

    pub fn isBool(self: Self) bool {
        return self == .boolean;
    }

    pub fn isNil(self: Self) bool {
        return self == .nil;
    }

    pub fn isNum(self: Self) bool {
        return self == .number;
    }

    pub fn isString(self: Self) bool {
        return self == .string;
    }

    pub fn asBool(self: Self) bool {
        std.debug.assert(self.isBool());
        return self.boolean;
    }

    pub fn asNumber(self: Self) f32 {
        std.debug.assert(self.isNum());
        return self.number;
    }

    pub fn asString(self: Self) *obj.String {
        std.debug.assert(self.isString());
        return self.string;
    }

    pub fn objType(self: Self) ObjType {
        return self.asObj().type;
    }

    pub fn isFalsey(self: Self) bool {
        return self.isNil() or (self.isBool() and !self.asBool());
    }

    pub fn checkEquality(a: *const Value, b: *const Value) bool {
        return switch (a.*) {
            .nil => switch (b.*) {
                .nil => true,
                else => false,
            },
            .boolean => switch (b.*) {
                .boolean => a.asBool() == b.asBool(),
                else => false,
            },
            .number => switch (b.*) {
                .number => a.asNumber() == b.asNumber(),
                else => false,
            },
            .string => switch (b.*) {
                .string => std.mem.eql(u8, a.asString().characters, b.asString().characters),
                else => false,
            },
        };
    }

    pub fn printValue(self: Self) void {
        switch (self) {
            .number => std.debug.print("'{d:.3}'\n", .{self.number}),
            .boolean => std.debug.print("'{any}'\n", .{self.boolean}),
            .nil => std.debug.print("'nil'\n", .{}),
            .string => std.debug.print("{s}\n", .{self.asString().characters}),
        }
    }

    pub fn logValue(self: Self) void {
        switch (self) {
            .number => Logger.log(std.log.Level.debug, .Result, "{d:.3}", .{self.number}),
            .boolean => Logger.log(std.log.Level.debug, .Result, "{any}", .{self.boolean}),
            .nil => Logger.log(std.log.Level.debug, .Result, "nil", .{}),
            .string => Logger.log(std.log.Level.debug, .Result, "{s}", .{self.asString().characters}),
        }
    }
};
