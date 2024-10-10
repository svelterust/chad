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
    alloc: std.mem.Allocator,
    index: usize,
    tokens: []lexer.Token,

    fn init(alloc: std.mem.Allocator, input: []lexer.Token) Parser {
        return Parser{ .alloc = alloc, .index = 0, .tokens = input };
    }

    fn next(self: *Parser) !?Node {
        while (self.index < self.tokens.len) {
            defer self.index += 1;
            const current = self.tokens[self.index];

            // Return node based on current token
            switch (current.type) {
                // Function
                .function => {
                    // Name of function
                    const name = self.tokens[self.index + 1].value;

                    // Parameters of function
                    const args_start = self.index + 2;
                    const args_end = blk: {
                        for (self.tokens[args_start..], 0..) |token, i|
                            if (token.type == .right_paren) break :blk args_start + i;
                        return error.FunctionMissingRightParen;
                    };
                    const arguments = if (args_end - args_start <= 1) [_]Node{} else return error.ParametersNotSupported;

                    // Body of function
                    const body_start = args_end + 2;
                    const body_end = blk: {
                        for (self.tokens[body_start..], 0..) |token, i|
                            if (token.type == .right_brace) break :blk body_start + i;
                        return error.FunctionMissingRightBrace;
                    };
                    const body = self.tokens[body_start..body_end];

                    // Create temporary parser with tokens of body and collect nodes
                    var parser = Parser.init(self.alloc, body);
                    var nodes = ArrayList(Node).init(self.alloc);
                    while (try parser.next()) |node|
                        try nodes.append(node);

                    // Return function
                    defer self.index += body_end;
                    return .{
                        .function_decl = .{
                            .name = name,
                            .arguments = &arguments,
                            .body = nodes.items,
                        },
                    };
                },

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
    var parser = Parser.init(alloc, tokens);
    var ast = ArrayList(Node).init(alloc);
    while (try parser.next()) |node|
        try ast.append(node);
    return ast;
}

test "parse" {
    // Arena allocator is optimal for compilers
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Lex input
    const input = @embedFile("examples/hello.chad");
    const tokens = try lexer.lex(alloc, input);
    for (tokens.items) |token|
        std.debug.print("{} {s}\n", .{ token.type, token.value });

    // Parse tokens
    const ast = try parse(alloc, tokens.items);
    for (ast.items) |node|
        std.debug.print("{}\n", .{node});
}
