const std = @import("std");
const chunk = @import("chunk.zig");

pub fn main() !void {
    var cnk = chunk.Chunk.init();
    try cnk.write(chunk.OpCode.OP_RETURN);
    try cnk.free();
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}

