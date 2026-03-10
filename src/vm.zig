const std = @import("std");

const BYTE = @import("op_code.zig").BYTE;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("op_code.zig").OpCode;
const ParseError = @import("parser.zig").ParseError;
const Parser = @import("parser.zig").Parser;
const Scanner = @import("scanner.zig").Scanner;
const Value = @import("value.zig").Value;
const ValueTag = @import("value.zig").ValueTag;

pub const RuntimeError = error{
    InvalidOperand,
    BufferTooSmall,
};

const STACK_MAX = 256;

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

    fn run(self: *Vm) !void {
        while (true) {
            const b = self.readByte();
            const instr: OpCode = @enumFromInt(b);
            switch (instr) {
                .OP_RETURN => {
                    const val = self.pop();
                    std.debug.print("Return: ", .{});
                    try printValue(val);
                    return;
                },
                .OP_NEGATE => {
                    const val = try unpack(self.pop().as(.Number));
                    const negated = -val;
                    self.push(try pack(negated));
                },
                .OP_ADD, OpCode.OP_SUBTRACT, OpCode.OP_MULTIPLY, OpCode.OP_DIVIDE => {
                    try self.interpretBinary(instr);
                },
                .OP_CONSTANT => {
                    const val = readConstant(self);
                    self.push(val);
                },
                .OP_NIL => {
                    self.push(Value.Nil);
                },
                .OP_TRUE => {
                    self.push(.{ .Bool = true });
                },
                .OP_FALSE => {
                    self.push(.{ .Bool = false });
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
        const b = try unpack(self.pop().as(.Number));
        const a = try unpack(self.pop().as(.Number));
        const res = switch (op) {
            .OP_ADD => a + b,
            .OP_SUBTRACT => a - b,
            .OP_MULTIPLY => a * b,
            .OP_DIVIDE => a / b,
            else => unreachable,
        };
        self.push(.{ .Number = res });
    }

    fn unpack(val: anytype) RuntimeError!payload(@TypeOf(val)) {
        return val catch RuntimeError.InvalidOperand;
    }

    fn pack(raw_value: anytype) RuntimeError!Value {
        const T = @TypeOf(raw_value);
        return switch (T) {
            f64 => Value{ .Number = raw_value },
            bool => Value{ .Bool = raw_value },
            void => Value{.Nil},
            else => RuntimeError.InvalidOperand,
        };
    }

    fn payload(comptime T: type) type {
        return switch (@typeInfo(T)) {
            .error_union => |eu| eu.payload,
            else => @compileError("Expecting an error union"),
        };
    }

    pub fn printValue(val: Value) !void {
        switch (val) {
            .Number => |n| std.debug.print("{}\n", .{n}),
            .Bool => |b| std.debug.print("{}\n", .{b}),
            .Nil => std.debug.print("nil", .{}),
        }
    }
};

pub const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};
