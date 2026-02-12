const std = @import("std");
const chunk = @import("chunk.zig");
const OpCode = @import("op_code.zig").OpCode;

pub fn disasChunk(cnk: chunk.Chunk, name: []const u8) !void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;

    while (offset < cnk.code.items.len) {
        offset += try disasInst(cnk, offset);
    }
}

pub fn disasInst(cnk: chunk.Chunk, idx: usize) !usize {
    var offset: usize = 0;

    std.debug.print("{:0>4} ", .{idx}); 

    const op_code: OpCode = @enumFromInt(cnk.code.items[idx]);
    offset += 1;

    var buf: [32]u8 = undefined;
    const r_o_pair = try op_code.render(&buf, cnk.code.items[idx + 1..]);
    offset += r_o_pair.offset;
    std.debug.print("{s}\n", .{r_o_pair.render});

    return offset;
}

