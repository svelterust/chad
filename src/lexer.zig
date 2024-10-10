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
    identifier,

    // Keywords
    function,
};

const Scanner = struct {
    index: usize,
    input: []const u8,

    fn init(input: []const u8) Scanner {
        return Scanner{ .index = 0, .input = input };
    }

    fn next(self: *Scanner) ?Token {
        while (self.index < self.input.len) {
            defer self.index += 1;
            const current = self.input[self.index];
            const slice = self.input[self.index .. self.index + 1];

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
                    for (self.input[self.index + 1 ..], 0..) |c, i| {
                        if (c == '"') {
                            const string = self.input[self.index .. self.index + i + 2];
                            self.index += string.len - 1;
                            return .{ .type = .string, .value = string };
                        }
                    }
                    return null;
                },

                // Identifier
                'a'...'z', 'A'...'Z', '_' => {
                    // Find end of identifier
                    for (self.input[self.index..], 0..) |c, i| {
                        if (!std.ascii.isAlphanumeric(c) and c != '_') {
                            const identifier = self.input[self.index .. self.index + i];
                            self.index += i - 1;
                            return .{ .type = .identifier, .value = identifier };
                        }
                    }
                },

                // Number
                '0'...'9' => {
                    // Find end of number
                    for (self.input[self.index..], 0..) |c, i| {
                        if (!std.ascii.isDigit(c)) {
                            const number = self.input[self.index .. self.index + i];
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

pub fn tokenize(alloc: std.mem.Allocator, input: []const u8) !ArrayList(Token) {
    // Lex tokens from input
    var tokens = ArrayList(Token).init(alloc);
    var scanner = Scanner.init(input);
    while (scanner.next()) |token|
        try tokens.append(token);
    return tokens;
}

test "tokenize" {
    const input = @embedFile("examples/hello.chad");
    var tokens = try tokenize(std.testing.allocator, input);
    defer tokens.deinit();
    for (tokens.items) |token| {
        std.debug.print("{any} {s}\n", .{ token.type, token.value });
    }
}
