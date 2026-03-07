const std = @import("std");
const cnk = @import("chunk.zig");
const debug = @import("debug.zig");
const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;
const Vm = @import("vm.zig").Vm;

const OpCode = @import("op_code.zig").OpCode;

const LINE_LENGTH: usize = 1024;
const FILE_SIZE: usize = 4096;

var gpa = std.heap.DebugAllocator(.{}){};
const alloc = gpa.allocator();

pub fn main() !void {
    const args = try std.process.argsAlloc(alloc);

    if (args.len == 1) {
        try repl();
    } else if (args.len == 2) {
        try runFile(args[2]);
    } else {
        std.log.err("Usage: zlox [filename]\n", .{});
    }
}

fn repl() !void {
    var buffer: [LINE_LENGTH]u8 = undefined;
    var reader = std.fs.File.stdin().reader(&buffer);
    const stdin = &reader.interface;

    while (true) {
        std.debug.print("> ", .{});
        const input = try stdin.takeDelimiter('\n');
        if (input) |line| {            
            try interpret(line);
        } else {
            break;
        }
    }
}

fn runFile(filename: []u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();
    const size = (try file.stat()).size;

    const buffer = try std.fs.cwd().readFileAlloc(alloc, filename, size);

    try interpret(buffer);
}

fn interpret(line: []u8) !void {
    const scanner = Scanner.init(line);
    var parser = try Parser.init(alloc);
    const chunk = try parser.compile(alloc, scanner);
    if (chunk) |valid_chunk| {
        var vm = Vm.init();
        vm.interpret(valid_chunk) catch |err| std.debug.print("{}", .{err});
    }
    else {
        for (parser.diagnostics.items) |diag| {
            std.debug.print("Line {}: syntax error: {s}\n", .{diag.token.line, @tagName(diag.error_type)});
        }
    }

    parser.deinit();
}
