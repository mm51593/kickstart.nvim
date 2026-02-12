const std = @import("std");
const chunk = @import("chunk.zig");
const OpCode = @import("op_code.zig").OpCode;
const debug = @import("debug.zig");

pub fn main() !void {
    var cnk = try chunk.Chunk.init();
    try cnk.write(u8, @intFromEnum(OpCode.OP_RETURN));

    try cnk.write(u8, @intFromEnum(OpCode.OP_CONSTANT));
    const addr = try cnk.addConstant(1.2);
    try cnk.write(@TypeOf(addr), addr);

    try cnk.write(u8, @intFromEnum(OpCode.OP_CONSTANT));
    const addr2 = try cnk.addConstant(3.2);
    try cnk.write(@TypeOf(addr2), addr2);

    try debug.disasChunk(cnk, "test chunk");
    cnk.free();
}
