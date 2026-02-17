const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Scanner = struct {
    start: usize,
    current: usize,
    source: []u8,
    line: usize,

    pub fn init(source: []u8) Scanner {
        return Scanner{ .start = 0, .current = 0, .source = source, .line = 1 };
    }

    pub fn scanToken(scan: *Scanner) Token {
        scan.skipWhitespace();
        scan.start = scan.current;

        if (scan.isAtEnd()) {
            return scan.makeToken(.EOF);
        }

        const c = scan.advance();

        if (std.ascii.isAlphabetic(c) or c == '_') {
            return scan.makeIdentifier();
        }

        if (std.ascii.isDigit(c)) {
            return scan.makeNumber();
        }

        switch (c) {
            '(' => return scan.makeToken(.LEFT_PAREN),
            ')' => return scan.makeToken(.RIGHT_PAREN),
            '{' => return scan.makeToken(.LEFT_BRACE),
            '}' => return scan.makeToken(.RIGHT_BRACE),
            ';' => return scan.makeToken(.SEMICOLON),
            ',' => return scan.makeToken(.COMMA),
            '.' => return scan.makeToken(.DOT),
            '-' => return scan.makeToken(.MINUS),
            '+' => return scan.makeToken(.PLUS),
            '/' => return scan.makeToken(.SLASH),
            '*' => return scan.makeToken(.STAR),

            '!' => {
                const tknType: TokenType = if (scan.match('=')) .BANG_EQUAL else .BANG;
                return scan.makeToken(tknType);
            },
            '=' => {
                const tknType: TokenType = if (scan.match('=')) .EQUAL_EQUAL else .EQUAL;
                return scan.makeToken(tknType);
            },
            '>' => {
                const tknType: TokenType = if (scan.match('=')) .GREATER_EQUAL else .GREATER;
                return scan.makeToken(tknType);
            },
            '<' => {
                const tknType: TokenType = if (scan.match('=')) .LESS_EQUAL else .LESS;
                return scan.makeToken(tknType);
            },

            '"' => return scan.makeString(),
            else => {},
        }
        
        return scan.makeError("Unexpected character.");
    }

    fn isAtEnd(scan: Scanner) bool {
        return scan.current >= scan.source.len;
    }

    fn makeToken(scan: Scanner, tokenType: TokenType) Token {
        return Token{ .tokenType = tokenType, .lexeme = scan.source[scan.start..scan.current], .line = scan.line };
    }

    fn makeError(scan: Scanner, msg: []const u8) Token {
        return Token{
            .tokenType = .ERROR,
            .lexeme = msg,
            .line = scan.line,
        };
    }

    fn makeString(scan: *Scanner) Token {
        while (scan.peek() != '=' and !scan.isAtEnd()) {
            if (scan.peek() == '\n') {
                scan.line += 1;
            }
            _ = scan.advance();
        }

        if (scan.isAtEnd()) {
            const msg = "Unterminated string.";
            return scan.makeError(msg[0..]);
        }

        // closing quote
        _ = scan.advance();
        return scan.makeToken(.STRING);
    }

    fn makeNumber(scan: *Scanner) Token {
        while (std.ascii.isDigit(scan.peek())) {
            _ = scan.advance();
        }

        if (scan.peek() == '.' and std.ascii.isDigit(scan.peekNext())) {
            // consume the '.'
            _ = scan.advance();

            while (std.ascii.isDigit(scan.peek())) {
                _ = scan.advance();
            }
        }

        return scan.makeToken(.NUMBER);
    }

    fn makeIdentifier(scan: *Scanner) Token {
        while (std.ascii.isAlphabetic(scan.peek()) or
            std.ascii.isDigit(scan.peek()) or scan.peek() == '_')
        {
            _ = scan.advance();
        }

        return scan.makeToken(scan.getIdentifierType());
    }

    fn peek(scan: Scanner) u8 {
        return scan.source[scan.current];
    }

    fn peekNext(scan: Scanner) u8 {
        if (scan.isAtEnd()) {
            return 0;
        }
        return scan.source[scan.current + 1];
    }

    fn advance(scan: *Scanner) u8 {
        const c = scan.peek();
        scan.current += 1;
        return c;
    }

    fn match(scan: *Scanner, expected: u8) bool {
        if (scan.isAtEnd()) {
            return false;
        }

        if (scan.peek() != expected) {
            return false;
        }

        scan.current += 1;
        return true;
    }

    fn skipWhitespace(scan: *Scanner) void {
        while (true) {
            if (scan.isAtEnd()) {
                return;
            }

            const c = scan.peek();
            if (std.ascii.isWhitespace(c)) {
                _ = scan.advance();
                if (c == '\n') {
                    scan.line += 1;
                }
                continue;
            }

            if (c == '/' and scan.peekNext() == '/') {
                while (scan.peek() != '\n' and !scan.isAtEnd()) {
                    _ = scan.advance();
                }
                continue;
            }

            return;
        }
    }

    fn getIdentifierType(scan: Scanner) TokenType {
        switch (scan.source[scan.start]) {
            'a' => return scan.checkKeyword(1, "nd", .AND),
            'c' => return scan.checkKeyword(1, "lass", .CLASS),
            'e' => return scan.checkKeyword(1, "lse", .ELSE),
            'f' => if (scan.current - scan.start > 1) {
                switch (scan.source[scan.start + 1]) {
                    'a' => return scan.checkKeyword(2, "lse", .FALSE),
                    'o' => return scan.checkKeyword(2, "r", .FOR),
                    else => {},
                }
            },
            'i' => return scan.checkKeyword(1, "f", .IF),
            'n' => return scan.checkKeyword(1, "il", .NIL),
            'o' => return scan.checkKeyword(1, "r", .OR),
            'p' => return scan.checkKeyword(1, "rint", .PRINT),
            'r' => return scan.checkKeyword(1, "eturn", .RETURN),
            's' => return scan.checkKeyword(1, "uper", .SUPER),
            't' => if (scan.current - scan.start > 1) {
                switch (scan.source[scan.start + 1]) {
                    'h' => return scan.checkKeyword(2, "is", .THIS),
                    'r' => return scan.checkKeyword(2, "ue", .TRUE),
                    else => {},
                }
            },
            'v' => return scan.checkKeyword(1, "ar", .VAR),
            'w' => return scan.checkKeyword(1, "hile", .WHILE),
            else => {},
        }

        return .IDENTIFIER;
    }

    fn checkKeyword(scan: Scanner, idx: usize, rest: []const u8, tokenType: TokenType) TokenType {
        if (scan.current - scan.start == rest.len + idx and
            std.mem.startsWith(u8, scan.source[scan.start + idx..], rest))
        {
            return tokenType;
        }
        return .IDENTIFIER;
    }
};
