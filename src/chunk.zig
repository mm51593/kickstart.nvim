const std = @import("std");
const mem = @import("memory.zig");

pub const OpCode = enum { OP_RETURN };

var gpa = std.heap.DebugAllocator(.{}){};
const allocator = gpa.allocator();

pub const Chunk = struct {
    count: u64,
    capacity: u64,
    code: []OpCode,

    pub fn init() Chunk {
        return Chunk{ .count = 0, .capacity = 0, .code = undefined };
    }

    pub fn write(self: *Chunk, byte: OpCode) !void {
        if (self.capacity < self.count + 1) {
            self.capacity = mem.growCapacity(self.capacity);
            self.code = try mem.reallocateArray(OpCode, self.code, self.capacity, allocator);
        }

        self.code[self.count] = byte;
        self.count += 1;
    }

    pub fn free(self: *Chunk) !void {
        self.count = 0;
        self.capacity = 0;
        self.code = try mem.reallocateArray(OpCode, self.code, 0, allocator);
    }
};
