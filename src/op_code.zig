const std = @import("std");

pub const RenderOffsetPair = struct { render: []const u8, offset: usize };

pub const OpCode = enum {
    OP_RETURN,

    pub fn render(self: OpCode) RenderOffsetPair {
        switch (self) {
            .OP_RETURN => {
                return RenderOffsetPair{ .render = @tagName(self), .offset = 1 };
            },
        }
    }
};
