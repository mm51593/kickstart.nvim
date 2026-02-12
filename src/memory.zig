const std = @import("std");

pub fn growCapacity(capacity: usize) usize {
    if (capacity < 8) {
        return 8;
    }

    return capacity * 2;
}

pub fn reallocateArray(comptime T: type, ptr: []T, new_size: usize, alloc: std.mem.Allocator) ![]T {
    return alloc.realloc(ptr, new_size) catch |err| (return err);
}
