const std = @import("std");
const lexer = @import("lexer.zig");
const assert = std.debug.assert;
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
        parameters: []const Node,
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
                    const name_start = self.index + 1;
                    assert(self.tokens[name_start].type == .identifier);
                    const name = self.tokens[name_start].value;

                    // Parameters of function
                    const args_start = self.index + 2;
                    assert(self.tokens[args_start].type == .left_paren);
                    const args_end = blk: {
                        for (self.tokens[args_start..], 0..) |token, i|
                            if (token.type == .right_paren) break :blk args_start + i;
                        return error.FunctionMissingRightParen;
                    };
                    assert(self.tokens[args_end].type == .right_paren);

                    // Parse arguments to node
                    const parameters = blk: {
                        var parser = Parser.init(self.alloc, self.tokens[args_start + 1 .. args_end]);
                        var nodes = ArrayList(Node).init(self.alloc);
                        while (try parser.next()) |node|
                            try nodes.append(node);
                        break :blk nodes;
                    };

                    // Body of function
                    const body_start = args_end + 1;
                    assert(self.tokens[body_start].type == .left_brace);
                    const body_end = blk: {
                        for (self.tokens[body_start..], 0..) |token, i|
                            if (token.type == .right_brace) break :blk body_start + i;
                        return error.FunctionMissingRightBrace;
                    };
                    assert(self.tokens[body_end].type == .right_brace);

                    // Parse body of function
                    const body = blk: {
                        var parser = Parser.init(self.alloc, self.tokens[body_start + 1 .. body_end]);
                        var nodes = ArrayList(Node).init(self.alloc);
                        while (try parser.next()) |node|
                            try nodes.append(node);
                        break :blk nodes;
                    };

                    // Return function declaration
                    defer self.index += body_end;
                    return .{ .function_decl = .{ .name = name, .parameters = parameters.items, .body = body.items } };
                },

                // Function call
                .identifier => {
                    const next_token = self.tokens[self.index + 1];
                    if (next_token.type == .left_paren) {
                        // Get name of function
                        const name = current.value;

                        // Find parameters of function
                        const params_start = self.index + 1;
                        assert(self.tokens[params_start].type == .left_paren);
                        const params_end = blk: {
                            for (self.tokens[params_start..], 0..) |token, i|
                                if (token.type == .right_paren) break :blk params_start + i;
                            return error.FunctionCallMissingRightParen;
                        };
                        assert(self.tokens[params_end].type == .right_paren);

                        // Parse arguments of function
                        const arguments = blk: {
                            var parser = Parser.init(self.alloc, self.tokens[params_start + 1 .. params_end]);
                            var nodes = ArrayList(Node).init(self.alloc);
                            while (try parser.next()) |node|
                                try nodes.append(node);
                            break :blk nodes;
                        };

                        // Return function call
                        const semicolon_start = params_end + 1;
                        assert(self.tokens[semicolon_start].type == .semicolon);
                        defer self.index += semicolon_start;
                        return .{ .function_call = .{ .name = name, .arguments = arguments.items } };
                    }
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
