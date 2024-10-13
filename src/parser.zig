const std = @import("std");
const lexer = @import("lexer.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

pub const Node = union(enum) {
    boolean: bool,
    number: i64,
    string: []const u8,
    let: struct {
        name: []const u8,
        value: *Node,
    },
    function_call: struct {
        name: []const u8,
        arguments: []const Node,
    },
    function_decl: struct {
        name: []const u8,
        parameters: []const Node,
        body: []const Node,
    },
};

fn findToken(token_type: lexer.TokenType, tokens: []lexer.Token, offset: usize) ?usize {
    for (tokens[offset..], 0..) |token, i|
        if (token.type == token_type) return offset + i;
    return null;
}

/// Takes a list of tokens and parses it into an Ast
pub fn parse(alloc: std.mem.Allocator, tokens: []lexer.Token) anyerror!ArrayList(Node) {
    var parser = Parser.init(alloc, tokens);
    var nodes = ArrayList(Node).init(alloc);
    while (try parser.next()) |node|
        try nodes.append(node);
    return nodes;
}

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
            const token = self.tokens[self.index];

            // Return node based on current token
            switch (token.type) {
                // Function
                .function => {
                    // Name of function
                    const name_start = self.index + 1;
                    assert(self.tokens[name_start].type == .identifier);
                    const name = self.tokens[name_start].value;

                    // Parameters of function
                    const args_start = self.index + 2;
                    assert(self.tokens[args_start].type == .left_paren);
                    const args_end = findToken(.right_paren, self.tokens, args_start) orelse return error.FunctionMissingRightParen;
                    assert(self.tokens[args_end].type == .right_paren);
                    const parameters = try parse(self.alloc, self.tokens[args_start + 1 .. args_end]);

                    // Body of function
                    const body_start = args_end + 1;
                    assert(self.tokens[body_start].type == .left_brace);
                    const body_end = findToken(.right_brace, self.tokens, body_start) orelse return error.FunctionMissingRightBrace;
                    assert(self.tokens[body_end].type == .right_brace);
                    const body = try parse(self.alloc, self.tokens[body_start + 1 .. body_end]);

                    // Return function declaration
                    defer self.index += body_end;
                    return .{ .function_decl = .{ .name = name, .parameters = parameters.items, .body = body.items } };
                },

                // Function call
                .identifier => {
                    const next_token = self.tokens[self.index + 1];
                    if (next_token.type == .left_paren) {
                        // Get name of function
                        const name = token.value;

                        // Find parameters of function
                        const params_start = self.index + 1;
                        assert(self.tokens[params_start].type == .left_paren);
                        const params_end = findToken(.right_paren, self.tokens, params_start) orelse return error.FunctionMissingRightParen;
                        assert(self.tokens[params_end].type == .right_paren);
                        const arguments = try parse(self.alloc, self.tokens[params_start + 1 .. params_end]);

                        // Return function call
                        const semicolon_start = params_end + 1;
                        assert(self.tokens[semicolon_start].type == .semicolon);
                        defer self.index += semicolon_start;
                        return .{ .function_call = .{ .name = name, .arguments = arguments.items } };
                    }
                },

                // Let
                .let => {
                    // Name of variable
                    const name = self.tokens[self.index + 1];
                    assert(name.type == .identifier);
                    assert(self.tokens[self.index + 2].type == .eq);

                    // Get value of variable
                    const value_start = self.index + 3;
                    const value = try parse(self.alloc, self.tokens[value_start .. value_start + 1]);
                    assert(self.tokens[self.index + 4].type == .semicolon);

                    // Return let statement
                    defer self.index = value_start + 1;
                    return .{ .let = .{ .name = name.value, .value = &value.items[0] } };
                },

                // Value
                .boolean => {
                    const boolean = if (std.mem.eql(u8, token.value, "true")) true else false;
                    return .{ .boolean = boolean };
                },
                .number => {
                    const number = try std.fmt.parseInt(i64, token.value, 10);
                    return .{ .number = number };
                },
                .string => {
                    return .{ .string = token.value };
                },

                // Unexpected token
                else => {
                    std.debug.print("Unexpected token: {}\n", .{token.type});
                    return error.UnexpectedToken;
                },
            }
        }
        return null;
    }
};

test "parse" {
    // Arena allocator is optimal for compilers
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Lex input
    const input = @embedFile("examples/hello.chad");
    const tokens = try lexer.lex(alloc, input);

    // Parse tokens
    const writer = std.io.getStdOut().writer();
    const ast = try parse(alloc, tokens.items);
    try writer.print("AST: ", .{});
    try std.json.stringify(&ast.items, .{ .whitespace = .indent_2 }, std.io.getStdOut().writer());
    try writer.print("\n\n", .{});
}
