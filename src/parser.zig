const std = @import("std");
const lexer = @import("lexer.zig");
const ArrayList = std.ArrayList;

const Value = union(enum) {
    boolean: bool,
    number: i64,
    string: []const u8,
};

const Node = union(enum) {
    value: Value,
    function_call: struct {
        name: []const u8,
        arguments: []const Node,
    },
    function_decl: struct {
        name: []const u8,
        arguments: []const Node,
        body: []const Node,
    },
};

const Parser = struct {
    index: usize,
    tokens: []lexer.Token,

    fn init(input: []lexer.Token) Parser {
        return Parser{ .index = 0, .tokens = input };
    }

    fn next(self: *Parser) !?Node {
        while (self.index < self.tokens.len) {
            defer self.index += 1;
            const current = self.tokens[self.index];

            // Return node based on current token
            switch (current.type) {
                // Value
                .boolean => {
                    const boolean = if (std.mem.eql(u8, current.value, "true")) true else false;
                    return .{ .value = .{ .boolean = boolean } };
                },
                .number => {
                    const number = try std.fmt.parseInt(i64, current.value, 10);
                    return .{ .value = .{ .number = number } };
                },
                .string => {
                    return .{ .value = .{ .string = current.value } };
                },

                // Unexpected character
                else => std.debug.print("Unexpected token: {}\n", .{current.type}),
            }
        }
        return null;
    }
};

pub fn parse(alloc: std.mem.Allocator, tokens: []lexer.Token) !ArrayList(Node) {
    // Parse tokens
    var ast = ArrayList(Node).init(alloc);
    var parser = Parser.init(tokens);
    while (try parser.next()) |node|
        try ast.append(node);
    return ast;
}

test "parse" {
    // Lex input
    const input = @embedFile("examples/hello.chad");
    const tokens = try lexer.lex(std.testing.allocator, input);
    for (tokens.items) |token|
        std.debug.print("{} {s}\n", .{ token.type, token.value });
    defer tokens.deinit();

    // Parse tokens
    const ast = try parse(std.testing.allocator, tokens.items);
    for (ast.items) |node|
        std.debug.print("{}\n", .{node});
    defer ast.deinit();
}
