const std = @import("std");
const cnk = @import("chunk.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");

const OpCode = @import("op_code.zig").OpCode;

pub fn main() !void {
    var v_m = vm.Vm.init();
    var chunk = try cnk.Chunk.init();

    try chunk.write(u8, @intFromEnum(OpCode.OP_CONSTANT), 1);
    const addr = try chunk.addConstant(1.2);
    try chunk.write(@TypeOf(addr), addr, 1);

    try chunk.write(u8, @intFromEnum(OpCode.OP_CONSTANT), 1);
    const addr2 = try chunk.addConstant(3.4);
    try chunk.write(@TypeOf(addr2), addr2, 1);

    try chunk.write(u8, @intFromEnum(OpCode.OP_ADD), 1);

    try chunk.write(u8, @intFromEnum(OpCode.OP_CONSTANT), 1);
    const addr3 = try chunk.addConstant(5.6);
    try chunk.write(@TypeOf(addr3), addr3, 1);

    try chunk.write(u8, @intFromEnum(OpCode.OP_DIVIDE), 2);

    try chunk.write(u8, @intFromEnum(OpCode.OP_NEGATE), 2);

    try chunk.write(u8, @intFromEnum(OpCode.OP_RETURN), 2);

    try debug.disasChunk(chunk, "test chunk");
    const ret = v_m.interpret(chunk);
    std.log.debug("{}\n", .{ret});

    chunk.free();
    v_m.free();
}
