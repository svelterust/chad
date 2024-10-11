const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

pub fn generate(alloc: std.mem.Allocator, ast: []parser.Node) ![]u8 {
    var codegen = CodeGen.init(alloc, ast);
    var buffer = std.ArrayList(u8).init(alloc);
    while (try codegen.next()) |code|
        try buffer.append(code);
    return buffer.items;
}

const CodeGen = struct {
    alloc: std.mem.Allocator,
    ast: []parser.Node,
    index: usize,
    indent: usize,

    fn init(alloc: std.mem.Allocator, ast: []parser.Node) CodeGen {
        return CodeGen{ .alloc = alloc, .ast = ast, .index = 0, .indent = 0 };
    }

    fn next(self: *CodeGen) !?[]u8 {
        while (self.index < self.ast.len) {
            defer self.index += 1;
            const node = self.ast[self.index];

            // Output Zig based on current node
            switch (node) {
                // Value types
                .boolean => |boolean| {
                    const output = try std.fmt.allocPrint(self.alloc, "{}", .{boolean});
                    return output;
                },
                .number => |number| {
                    const output = try std.fmt.allocPrint(self.alloc, "{d}", .{number});
                    return output;
                },
                .string => |string| return string,
                .function_call => |function_call| {
                    // Write name and parameters
                    var buffer = std.ArrayList(u8).init(self.alloc);
                    try buffer.append(function_call.name);
                    try buffer.addOne('(');
                    for (function_call.arguments) |argument| {
                        const code = try generate(self.alloc, .{argument});
                        try buffer.append(code);
                    }
                    try buffer.append(");\n");
                    return buffer.items;
                },
                else => {},
            }
        }
    }
};

test "codegen" {
    // Arena allocator is optimal for compilers
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Lex input
    const input = @embedFile("examples/hello.chad");
    const tokens = try lexer.lex(alloc, input);

    // Parse tokens
    const writer = std.io.getStdOut().writer();
    const ast = try parser.parse(alloc, tokens.items);

    // Generate code
    const code = try generate(alloc, ast.items);
    try writer.print("Code:\n", .{});
    try writer.writeAll(code);
    try writer.print("\n\n", .{});
}
