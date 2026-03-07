const Allocator = @import("std").mem.Allocator;
const fmt = @import("std").fmt;
const meta = @import("std").meta;

const INITIAL_CAPACITY = 8;
const ArrayList = @import("std").ArrayList;

pub const ValueError = error{
    InvalidType,
};

pub const ValueTag = enum {
    Number,
    Bool,
    Nil,
};

pub const Value = union(ValueTag) {
    Number: f64,
    Bool: bool,
    Nil,

    pub fn as(self: Value, comptime tag: ValueTag) ValueError!meta.TagPayload(Value, tag) {
        if (meta.activeTag(self) != tag) {
            return ValueError.InvalidType;
        }

        return @field(self, @tagName(tag));
    }
};

pub const ValueArray = struct {
    alloc: Allocator,
    values: ArrayList(Value),

    pub fn init(alloc: Allocator) !ValueArray {
        const values = try ArrayList(Value).initCapacity(alloc, INITIAL_CAPACITY);
        return ValueArray{ .alloc = alloc, .values = values };
    }

    pub fn write(self: *ValueArray, value: Value) !void {
        try self.values.append(self.alloc, value);
    }

    pub fn deinit(self: *ValueArray) void {
        self.values.deinit(self.alloc);
    }
};

