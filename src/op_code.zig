const std = @import("std");
const value = @import("value.zig");

pub const RenderOffsetPair = struct { render: []const u8, offset: usize };

pub const BYTE = u8;
pub const address = usize;

pub const OpCode = enum(BYTE) {
    OP_RETURN,
    OP_CONSTANT,

    pub fn render(self: OpCode, buf: []u8, bytestream: []BYTE) !RenderOffsetPair {
        switch (self) {
            .OP_RETURN => {
                return RenderOffsetPair{ .render = @tagName(self), .offset = 0 };
            },
            .OP_CONSTANT => {
                const size = @sizeOf(address);
                const val = std.mem.readInt(usize, bytestream[0..size], std.builtin.Endian.little);
                const rend = try std.fmt.bufPrint(buf, "{s} {}", .{@tagName(self), val});

                return RenderOffsetPair{ .render = rend, .offset = size }; 
            }
        }
    }
};
