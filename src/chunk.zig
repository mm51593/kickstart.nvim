const std = @import("std");
const mem = @import("memory.zig");
const op_code = @import("op_code.zig");

var gpa = std.heap.DebugAllocator(.{}){};
const allocator = gpa.allocator();

const INITIAL_CAPACITY = 8;

pub const Chunk = struct {
    count: usize,
    code: []op_code.OpCode,

    pub fn init() !Chunk {
        const block = try allocator.alloc(op_code.OpCode, INITIAL_CAPACITY);
        return Chunk{ .count = 0, .code = block };
    }

    pub fn write(self: *Chunk, byte: op_code.OpCode) !void {
        if (self.code.len < self.count + 1) {
            self.code.len = mem.growCapacity(self.code.len);
            self.code = try mem.reallocateArray(op_code.OpCode, self.code, self.code.len, allocator);
        }

        self.code[self.count] = byte;
        self.count += 1;
    }

    pub fn free(self: *Chunk) void {
        self.count = 0;
        allocator.free(self.code);
    }
};
