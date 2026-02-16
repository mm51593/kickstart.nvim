const std = @import("std");
const cnk = @import("chunk.zig");
const value = @import("value.zig");
const BYTE = @import("op_code.zig").BYTE;
const OpCode = @import("op_code.zig").OpCode;

const STACK_MAX = 256;

pub const Vm = struct {
    chunk: cnk.Chunk,
    ip: [*]u8,
    stack: [STACK_MAX]value.Value,
    sp: [*]value.Value,

    pub fn init() Vm {
        var vm = Vm{ .chunk = undefined, .ip = undefined, .stack = undefined, .sp = undefined };
        vm.sp = &vm.stack;
        return vm;
    }

    pub fn free(_: Vm) void {
    }

    pub fn interpret(_: *Vm, _: []u8) InterpretResult {
        return .INTERPRET_OK;
    }

    fn run(vm: *Vm) InterpretResult {
        while (true) {
            const instr: OpCode = @enumFromInt(readByte(vm));
            switch (instr) {
                .OP_RETURN => {
                    const val = vm.pop();
                    std.debug.print("Return: {}\n", .{val});
                    return InterpretResult.INTERPRET_OK;
                },
                .OP_NEGATE => {
                    const val = vm.pop();
                    vm.push(-val);
                },
                .OP_ADD, OpCode.OP_SUBTRACT, OpCode.OP_MULTIPLY, OpCode.OP_DIVIDE => {
                    vm.interpretBinary(instr);
                },
                .OP_CONSTANT => {
                    const val = readConstant(vm);
                    vm.push(val);
                }
            }
        }
    }

    fn readByte(vm: *Vm) BYTE {
        const byte: u8 = vm.ip[0];
        vm.ip += 1;
        return byte;
    }

    fn readConstant(vm: *Vm) value.Value {
        return vm.chunk.constants.values.items[vm.readByte()];
    }

    fn push(vm: *Vm, val: value.Value) void {
        vm.sp[0] = val;
        vm.sp += 1;
    }

    fn pop(vm: *Vm) value.Value {
        vm.sp -= 1;
        return vm.sp[0];
    }

    fn printStack(vm: Vm) void {
        for (&vm.stack..vm.sp) |slot| {
            std.debug.print("[{}]", .{slot.*});
        }
    }

    fn interpretBinary(vm: *Vm, op: OpCode) void {
        const b = vm.pop();
        const a = vm.pop();
        const res = switch (op) {
            .OP_ADD => a + b,
            .OP_SUBTRACT => a - b,
            .OP_MULTIPLY => a * b,
            .OP_DIVIDE => a / b,
            else => unreachable
        };
        vm.push(res);
    }
};

pub const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};
