const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

pub fn codegen(alloc: std.mem.Allocator, ast: []const parser.Node) ![]const u8 {
    // Include header
    var buffer = std.ArrayList(u8).init(alloc);
    try buffer.appendSlice("const std = @import(\"std\");\n\n");

    // Generate code
    const file = try generate(alloc, ast);
    try buffer.appendSlice(file);
    return buffer.items;
}

fn generate(alloc: std.mem.Allocator, ast: []const parser.Node) anyerror![]const u8 {
    var generator = Generator.init(alloc, ast);
    var buffer = std.ArrayList(u8).init(alloc);
    while (try generator.next()) |code|
        try buffer.appendSlice(code);
    return buffer.items;
}

const Generator = struct {
    alloc: std.mem.Allocator,
    ast: []const parser.Node,
    index: usize,
    indent: usize,

    fn init(alloc: std.mem.Allocator, ast: []const parser.Node) Generator {
        return Generator{ .alloc = alloc, .ast = ast, .index = 0, .indent = 0 };
    }

    fn next(self: *Generator) !?[]const u8 {
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

                // Variables
                .let => |let| {
                    // Write name and parameters
                    var buffer = std.ArrayList(u8).init(self.alloc);
                    try buffer.appendSlice("const ");
                    try buffer.appendSlice(let.name);
                    try buffer.appendSlice(" = ");
                    const code = try generate(self.alloc, &.{let.value.*});
                    try buffer.appendSlice(code);
                    try buffer.appendSlice(";\n");
                    return buffer.items;
                },

                // Function call
                .function_call => |function_call| {
                    // Write name and parameters
                    var buffer = std.ArrayList(u8).init(self.alloc);

                    // If name is special, translate it
                    if (std.mem.eql(u8, function_call.name, "print")) {
                        try buffer.appendSlice("try std.io.getStdOut().writer().print(\"{any}\\n\", .{ ");
                    } else {
                        try buffer.appendSlice(function_call.name);
                        try buffer.append('(');
                    }
                    for (function_call.arguments) |argument| {
                        const code = try generate(self.alloc, &.{argument});
                        try buffer.appendSlice(code);
                    }
                    if (std.mem.eql(u8, function_call.name, "print"))
                        try buffer.appendSlice(" }");
                    try buffer.appendSlice(");\n");
                    return buffer.items;
                },

                // Function declaration
                .function_decl => |function_decl| {
                    // Write function declaration
                    var buffer = std.ArrayList(u8).init(self.alloc);
                    if (std.mem.eql(u8, function_decl.name, "main"))
                        try buffer.appendSlice("pub ");
                    try buffer.appendSlice("fn ");
                    try buffer.appendSlice(function_decl.name);
                    try buffer.append('(');
                    for (function_decl.parameters) |parameter| {
                        const code = try generate(self.alloc, &.{parameter});
                        try buffer.appendSlice(code);
                    }
                    try buffer.appendSlice(") !void {\n");

                    // Indend body
                    self.indent += 4;
                    for (function_decl.body) |body| {
                        const code = try generate(self.alloc, &.{body});
                        if (self.indent > 0) {
                            try buffer.appendSlice("    ");
                        }
                        try buffer.appendSlice(code);
                    }
                    self.indent -= 4;
                    try buffer.appendSlice("}\n");
                    return buffer.items;
                },
            }
        }
        return null;
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
    const code = try codegen(alloc, ast.items);
    try writer.writeAll(code);
    try writer.print("\n", .{});
}
