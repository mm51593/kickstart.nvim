const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const Value = @import("value.zig").Value;
const ValueTag = @import("value.zig").ValueTag;
const ValueError = @import("value.zig").ValueError;
const BYTE = @import("op_code.zig").BYTE;
const OpCode = @import("op_code.zig").OpCode;
const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;
const ParseError = @import("parser.zig").ParseError;

const STACK_MAX = 256;

pub const RuntimeError = ValueError;

pub const Vm = struct {
    chunk: Chunk,
    ip: [*]u8,
    stack: [STACK_MAX]Value,
    sp: [*]Value,

    pub fn init() Vm {
        var vm = Vm{ .chunk = undefined, .ip = undefined, .stack = undefined, .sp = undefined };
        vm.sp = &vm.stack;
        return vm;
    }

    pub fn deinit(_: Vm) void {}

    pub fn interpret(vm: *Vm, chunk: Chunk) !void {
        vm.chunk = chunk;
        vm.ip = vm.chunk.code.items.ptr;

        try vm.run();
    }

    fn run(self: *Vm) RuntimeError!void {
        while (true) {
            const b = self.readByte();
            const instr: OpCode = @enumFromInt(b);
            switch (instr) {
                .OP_RETURN => {
                    const val = self.pop();
                    std.debug.print("Return: {}\n", .{val});
                    return;
                },
                .OP_NEGATE => {
                    const val = self.pop();
                    const negated = -try val.as(.Number);
                    self.push(try pack(f64, negated));
                },
                .OP_ADD, OpCode.OP_SUBTRACT, OpCode.OP_MULTIPLY, OpCode.OP_DIVIDE => {
                    try self.interpretBinary(instr);
                },
                .OP_CONSTANT => {
                    const val = readConstant(self);
                    self.push(val);
                },
            }
        }
    }

    fn readByte(self: *Vm) BYTE {
        const byte: u8 = self.ip[0];
        self.ip += 1;
        return byte;
    }

    fn readConstant(self: *Vm) Value {
        return self.chunk.constants.values.items[self.readByte()];
    }

    fn push(self: *Vm, val: Value) void {
        self.sp[0] = val;
        self.sp += 1;
    }

    fn pop(self: *Vm) Value {
        self.sp -= 1;
        return self.sp[0];
    }

    fn printStack(self: Vm) void {
        for (&self.stack..self.sp) |slot| {
            std.debug.print("[{}]", .{slot.*});
        }
    }

    fn interpretBinary(self: *Vm, op: OpCode) RuntimeError!void {
        const b = try self.pop().as(.Number);
        const a = try self.pop().as(.Number);
        const res = switch (op) {
            .OP_ADD => a + b,
            .OP_SUBTRACT => a - b,
            .OP_MULTIPLY => a * b,
            .OP_DIVIDE => a / b,
            else => unreachable,
        };
        self.push(.{ .Number = res });
    }

    fn pack(comptime T: type, raw_value: T) ValueError!Value {
        return switch (T) {
            f64 => Value{ .Number = raw_value },
            bool => Value{ .Bool = raw_value },
            void => Value{ .Nil },
            else => ValueError.InvalidType,
        };
    }
};

pub const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};
