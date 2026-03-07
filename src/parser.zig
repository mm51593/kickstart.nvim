const std = @import("std");

const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("op_code.zig").OpCode;
const Scanner = @import("scanner.zig").Scanner;
const Token = @import("token.zig").Token;
const Value = @import("value.zig").Value;

pub const Parser = struct {
    pub const Error = union(enum) {
        TooManyConstants,
        InvalidCharacter,
        NotANumber,
        UnexpectedToken: struct { expected: Token.Type },
        ExpectedExpression,
    };

    pub const Diagnostic = struct {
        error_type: Error,
        token: Token,
    };

    alloc: std.mem.Allocator,
    current: Token,
    previous: Token,
    diagnostics: std.ArrayList(Diagnostic),
    _chunk: ?Chunk,
    _scanner: Scanner,

    pub fn init(alloc: std.mem.Allocator) !Parser {
        return Parser{
            .alloc = alloc,
            .current = undefined,
            .previous = undefined,
            .diagnostics = try std.ArrayList(Diagnostic).initCapacity(alloc, 4),
            ._chunk = undefined,
            ._scanner = undefined,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.diagnostics.deinit(self.alloc);
    }

    pub fn compile(self: *Parser, alloc: std.mem.Allocator, scanner: Scanner) !?Chunk {
        self._chunk = try Chunk.init(alloc);
        self._scanner = scanner;

        try self.advance();
        try self.getExpr();

        try self.consume(.EOF);
        try self.endCompiler();

        return self._chunk;
    }

    fn getExpr(self: *Parser) !void {
        try self.parsePrecendence(.Assignment);
    }

    fn getNumber(self: *Parser) !void {
        const val = std.fmt.parseFloat(f64, self.previous.lexeme) catch {
            return try self.reportError(.NotANumber);
        };
        try self.emitConstant(Value{ .Number = val });
    }

    fn getGrouping(self: *Parser) !void {
        try self.getExpr();
        try self.consume(.RIGHT_PAREN);
        unreachable;
    }

    fn getBinary(self: *Parser) !void {
        const op = self.previous.token_type;
        const rule = ParseRule.getRule(op);
        const next_precedence: Precedence = @enumFromInt(@intFromEnum(rule.precedence) + 1);
        try self.parsePrecendence(next_precedence);

        switch (op) {
            .PLUS => try self.emitOp(.OP_ADD),
            .MINUS => try self.emitOp(.OP_SUBTRACT),
            .STAR => try self.emitOp(.OP_MULTIPLY),
            .SLASH => try self.emitOp(.OP_DIVIDE),
            else => unreachable,
        }
    }

    fn getUnary(self: *Parser) !void {
        const op = self.previous.token_type;

        try self.parsePrecendence(.Unary);

        switch (op) {
            .MINUS => try self.emitOp(.OP_NEGATE),
            else => unreachable,
        }
    }

    fn parsePrecendence(self: *Parser, prec: Precedence) !void {
        try self.advance();
        const prefix_rule = ParseRule.getRule(self.previous.token_type).prefix;

        if (prefix_rule) |valid_prefix_rule| {
            try valid_prefix_rule(self);
        } else {
            return try self.reportError(.ExpectedExpression);
        }

        while (prec.cmp(ParseRule.getRule(self.current.token_type).precedence) <= 0) {
            try self.advance();
            const infix_rule = ParseRule.getRule(self.previous.token_type).infix;
            if (infix_rule) |valid_infix_rule| {
                try valid_infix_rule(self);
            } else {
                return try self.reportError(.ExpectedExpression);
            }
        }
    }

    fn emitOp(self: *Parser, op: OpCode) !void {
        if (self._chunk) |*chunk| {
            try chunk.writeOp(op, self.previous.line);
        }
    }

    fn emitByte(self: *Parser, byte: u8) !void {
        if (self._chunk) |*chunk| {
            try chunk.write(u8, byte, self.previous.line);
        }
    }

    fn emitConstant(self: *Parser, value: Value) !void {
        try self.emitOp(OpCode.OP_CONSTANT);
        try self.emitByte(try makeConstant(self, value));
    }

    fn makeConstant(self: *Parser, value: Value) !u8 {
        const addr = if (self._chunk) |*chunk|
            try chunk.addConstant(value)
        else
            0;

        if (addr > std.math.maxInt(u8)) {
            try self.reportError(.TooManyConstants);
        }

        return @intCast(addr);
    }

    fn endCompiler(self: *Parser) !void {
        try self.emitOp(OpCode.OP_RETURN);
    }

    fn advance(self: *Parser) !void {
        self.previous = self.current;

        while (true) {
            self.current = self._scanner.scanToken();
            if (self.current.token_type != .ERROR) {
                break;
            }

            try self.reportErrorAtCurrent(.InvalidCharacter);
        }
    }

    fn consume(self: *Parser, token_type: Token.Type) !void {
        if (self.current.token_type == token_type) {
            try self.advance();
            return;
        }

        try self.reportErrorAtCurrent(.{ .UnexpectedToken = .{ .expected = token_type } });
    }

    fn reportErrorAtCurrent(self: *Parser, err: Error) !void {
        try self.reportErrorAt(self.current, err);
    }

    fn reportError(self: *Parser, err: Error) !void {
        try self.reportErrorAt(self.previous, err);
    }

    fn reportErrorAt(self: *Parser, token: Token, err: Error) !void {
        self.deallocChunk();

        try self.diagnostics.append(self.alloc, Diagnostic{ .error_type = err, .token = token });
    }

    fn deallocChunk(self: *Parser) void {
        if (self._chunk) |*chunk| {
            chunk.deinit();
        }

        self._chunk = null;
    }
};

const Precedence = enum(i8) {
    None,
    Assignment,
    Or,
    And,
    Equality,
    Comparison,
    Term,
    Factor,
    Unary,
    Call,
    Primary,

    fn cmp(self: Precedence, other: Precedence) i8 {
        return @intFromEnum(self) - @intFromEnum(other);
    }
};

const ParseFn = *const fn (*Parser) anyerror!void;
const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,

    fn getRule(token_type: Token.Type) ParseRule {
        return switch (token_type) {
            .LEFT_PAREN => ParseRule{ .prefix = Parser.getGrouping, .infix = null, .precedence = Precedence.None },
            .RIGHT_PAREN => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .LEFT_BRACE => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .RIGHT_BRACE => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .COMMA => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .DOT => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .MINUS => ParseRule{ .prefix = Parser.getUnary, .infix = Parser.getBinary, .precedence = Precedence.Term },
            .PLUS => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Term },
            .SEMICOLON => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .SLASH => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Factor },
            .STAR => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Factor },
            .BANG => ParseRule{ .prefix = Parser.getUnary, .infix = null, .precedence = Precedence.None },
            .BANG_EQUAL => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Comparison },
            .EQUAL => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .EQUAL_EQUAL => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Comparison },
            .GREATER => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Comparison },
            .GREATER_EQUAL => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Comparison },
            .LESS => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Comparison },
            .LESS_EQUAL => ParseRule{ .prefix = null, .infix = Parser.getBinary, .precedence = Precedence.Comparison },
            .IDENTIFIER => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .STRING => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .NUMBER => ParseRule{ .prefix = Parser.getNumber, .infix = null, .precedence = Precedence.None },
            .AND => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .CLASS => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .ELSE => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .FALSE => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .FUN => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .FOR => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .IF => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .NIL => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .OR => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .PRINT => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .RETURN => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .SUPER => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .THIS => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .TRUE => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .VAR => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .WHILE => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .EOF => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
            .ERROR => ParseRule{ .prefix = null, .infix = null, .precedence = Precedence.None },
        };
    }
};
