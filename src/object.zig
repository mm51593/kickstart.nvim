const Allocator = @import("std").mem.Allocator;
const Order = @import("std").math.Order;
const debug = @import("std").debug;
const mem = @import("std").mem;

pub const ObjError = error {
    InvalidType,
};

pub const ObjType = enum {
    OBJ_STRING,
};

pub const Obj = struct {
    type: ObjType,

    pub fn as(self: *const Obj, comptime T: type) ObjError!*T {
        if (self.type != T.tag) {
            return ObjError.InvalidType;
        }
        return @alignCast(@constCast(@fieldParentPtr("obj", self)));
    }

    pub fn print(self: *const Obj) ObjError!void {
        switch (self.type) {
            .OBJ_STRING => (try self.as(ObjString)).print(),
        }
    }

    pub fn equals(a: *Obj, b: *Obj) ObjError!bool {
        if (a.type != b.type) {
            return false;
        }

        return switch (a.type) {
            .OBJ_STRING => ObjString.cmp(try a.as(ObjString), try b.as(ObjString)) == .eq,
        };
    }
};

pub const ObjString = struct {
    pub const tag = ObjType.OBJ_STRING;
    obj: Obj,
    chars: []u8,

    pub fn init(alloc: Allocator, chars: []u8) !*ObjString {
        var p = try alloc.create(ObjString);
        p.obj = .{ .type = .OBJ_STRING };
        p.chars = chars;
        return p;
    }

    pub fn print(self: *ObjString) void {
        debug.print("{s}\n", .{self.chars});
    }

    pub fn cmp(a: *ObjString, b: *ObjString) Order {
        const res = mem.order(u8, a.chars, b.chars);
        return res;
    }

    pub fn concatenate(alloc: Allocator, a: *ObjString, b: *ObjString) !*ObjString {
        const len = a.chars.len + b.chars.len;
        const chars = try alloc.alloc(u8, len);
        @memcpy(chars, a.chars.ptr);
        @memcpy(chars[a.chars.len..], b.chars.ptr);

        return try ObjString.init(alloc, chars);
    }
};
