const std = @import("std");
const ArrayList = std.ArrayList;

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

pub const TokenType = enum {
    // Single character
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    semicolon,

    // Literals
    string,
    number,
    boolean,
    identifier,

    // Keywords
    function,
};

const Lexer = struct {
    index: usize,
    src: []const u8,

    fn init(input: []const u8) Lexer {
        return Lexer{ .index = 0, .src = input };
    }

    fn next(self: *Lexer) ?Token {
        while (self.index < self.src.len) {
            defer self.index += 1;
            const current = self.src[self.index];
            const slice = self.src[self.index .. self.index + 1];

            // Return token based on current character
            switch (current) {
                // Skip whitespace
                ' ', '\t', '\n' => continue,

                // Single character tokens
                '(' => return .{ .type = .left_paren, .value = slice },
                ')' => return .{ .type = .right_paren, .value = slice },
                '{' => return .{ .type = .left_brace, .value = slice },
                '}' => return .{ .type = .right_brace, .value = slice },
                ';' => return .{ .type = .semicolon, .value = slice },

                // String
                '"' => {
                    // Find matching quote
                    for (self.src[self.index + 1 ..], 0..) |c, i| {
                        if (c == '"') {
                            const string = self.src[self.index .. self.index + i + 2];
                            self.index += string.len - 1;
                            return .{ .type = .string, .value = string };
                        }
                    }
                    return null;
                },

                // Identifier
                'a'...'z', 'A'...'Z', '_' => {
                    // Find end of identifier
                    for (self.src[self.index..], 0..) |c, i| {
                        if (!std.ascii.isAlphanumeric(c) and c != '_') {
                            const identifier = self.src[self.index .. self.index + i];
                            self.index += i - 1;

                            // Check if identifier is a keyword
                            if (std.mem.eql(u8, identifier, "fn")) {
                                return .{ .type = .function, .value = identifier };
                            } else if (std.mem.eql(u8, identifier, "true") or std.mem.eql(u8, identifier, "false")) {
                                return .{ .type = .boolean, .value = identifier };
                            } else {
                                return .{ .type = .identifier, .value = identifier };
                            }
                        }
                    }
                },

                // Number
                '-', '0'...'9' => {
                    // Find end of number
                    for (self.src[self.index..], 0..) |c, i| {
                        if (!std.ascii.isDigit(c) and !(c == '-' and i == 0)) {
                            const number = self.src[self.index .. self.index + i];
                            self.index += i - 1;
                            return .{ .type = .number, .value = number };
                        }
                    }
                },

                // Unexpected character
                else => std.debug.print("Unexpected character: {s}\n", .{slice}),
            }
        }
        return null;
    }
};

pub fn lex(alloc: std.mem.Allocator, input: []const u8) !ArrayList(Token) {
    // Lex input
    var tokens = ArrayList(Token).init(alloc);
    var scanner = Lexer.init(input);
    while (scanner.next()) |token|
        try tokens.append(token);
    return tokens;
}

test "lex" {
    // Lex input
    const input = @embedFile("examples/hello.chad");
    var tokens = try lex(std.testing.allocator, input);
    std.debug.assert(tokens.items.len == 16);
    defer tokens.deinit();
}
