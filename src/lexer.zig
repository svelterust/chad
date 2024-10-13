const std = @import("std");
const assert = std.debug.assert;
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
    eq,

    // Literals
    string,
    number,
    boolean,
    identifier,

    // Keywords
    @"if",
    let,
    function,
};

/// Takes input and lexes it into a list of tokens
pub fn lex(alloc: std.mem.Allocator, input: []const u8) !ArrayList(Token) {
    // Lex input
    var tokens = ArrayList(Token).init(alloc);
    var scanner = Lexer.init(input);
    while (try scanner.next()) |token|
        try tokens.append(token);
    return tokens;
}

const Lexer = struct {
    index: usize,
    src: []const u8,

    fn init(input: []const u8) Lexer {
        return Lexer{ .index = 0, .src = input };
    }

    fn next(self: *Lexer) !?Token {
        while (self.index < self.src.len) {
            defer self.index += 1;
            const character = self.src[self.index];
            const slice = self.src[self.index .. self.index + 1];

            // Return token based on current character
            switch (character) {
                // Skip whitespace
                ' ', '\t', '\n' => continue,

                // Skip comments
                '/' => if (self.src[self.index + 1] == '/') {
                    // Find end of comment
                    const newline = std.mem.indexOf(u8, self.src[self.index..], &.{'\n'}) orelse return null;
                    self.index += newline;
                },

                // Single character tokens
                '(' => return .{ .type = .left_paren, .value = slice },
                ')' => return .{ .type = .right_paren, .value = slice },
                '{' => return .{ .type = .left_brace, .value = slice },
                '}' => return .{ .type = .right_brace, .value = slice },
                ';' => return .{ .type = .semicolon, .value = slice },
                '=' => return .{ .type = .eq, .value = slice },

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
                            } else if (std.mem.eql(u8, identifier, "if")) {
                                return .{ .type = .@"if", .value = identifier };
                            } else if (std.mem.eql(u8, identifier, "let")) {
                                return .{ .type = .let, .value = identifier };
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
                else => {
                    std.debug.print("Unexpected character: {s}\n", .{slice});
                    return error.UnexpectedCharacter;
                },
            }
        }
        return null;
    }
};

test "lex" {
    // Arena allocator is optimal for compilers
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Lex input
    const writer = std.io.getStdOut().writer();
    const input = @embedFile("examples/hello.chad");
    const tokens = try lex(alloc, input);
    try writer.print("Tokens: ", .{});
    try std.json.stringify(&tokens.items, .{ .whitespace = .indent_2 }, std.io.getStdOut().writer());
    try writer.print("\n\n", .{});
}
