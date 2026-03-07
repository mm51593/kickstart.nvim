const std = @import("std");
const op_code = @import("op_code.zig");
const value = @import("value.zig");

const INITIAL_CAPACITY = 8;
const BYTE = op_code.BYTE;

pub const Chunk = struct {
    alloc: std.mem.Allocator,
    code: std.ArrayList(BYTE),
    lines: std.ArrayList(usize),
    constants: value.ValueArray,

    pub fn init(alloc: std.mem.Allocator) !Chunk {
        const code = try std.ArrayList(BYTE).initCapacity(alloc, INITIAL_CAPACITY);
        const lines = try std.ArrayList(usize).initCapacity(alloc, INITIAL_CAPACITY);
        const constants = try value.ValueArray.init(alloc);
        return Chunk{ .alloc = alloc, .code = code, .lines = lines, .constants = constants };
    }

    pub fn writeOp(self: *Chunk, op: op_code.OpCode, line: usize) !void {
        try self.write(u8, @intFromEnum(op), line);
    }

    pub fn write(self: *Chunk, comptime T: type, data: T, line: usize) !void {
        var buf: [@sizeOf(T)]BYTE = undefined;
        std.mem.writeInt(T, &buf, data, std.builtin.Endian.little);

        try self.code.appendSlice(self.alloc, &buf);

        try self.lines.appendNTimes(self.alloc, line, @sizeOf(T) / @sizeOf(BYTE));
    }

    pub fn addConstant(self: *Chunk, val: value.Value) !usize {
        try self.constants.write(val);
        return self.constants.values.items.len - 1;
    }

    pub fn deinit(self: *Chunk) void {
        self.constants.deinit();
        self.lines.deinit(self.alloc);
        self.code.deinit(self.alloc);
    }
};
