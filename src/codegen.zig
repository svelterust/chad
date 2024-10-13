const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Buffer = std.io.BufferedWriter(4096, ArrayList(u8).Writer);

pub fn codegen(alloc: std.mem.Allocator, ast: []const parser.Node) ![]const u8 {
    // Include header
    var output = std.ArrayList(u8).init(alloc);
    var buffer = std.io.bufferedWriter(output.writer());
    _ = try buffer.write("const std = @import(\"std\");\n\n");

    // Generate code
    var generator = Generator.init(alloc, ast, &buffer);
    try generator.next();
    try buffer.flush();
    return output.items;
}

// Helper function to generate sections of code
fn generate(generator: *Generator, ast: []const parser.Node) !void {
    var temp_generator = Generator.init(generator.alloc, ast, generator.buffer);
    try temp_generator.next();
}

const Generator = struct {
    // State
    alloc: std.mem.Allocator,
    ast: []const parser.Node,
    buffer: *Buffer,
    index: usize,

    fn init(alloc: std.mem.Allocator, ast: []const parser.Node, buffer: *Buffer) Generator {
        return Generator{
            .alloc = alloc,
            .ast = ast,
            .buffer = buffer,
            .index = 0,
        };
    }

    fn next(self: *Generator) anyerror!void {
        // Get writer
        var writer = self.buffer.writer();
        while (self.index < self.ast.len) {
            defer self.index += 1;
            const node = self.ast[self.index];

            // Output Zig based on current node
            switch (node) {
                // Value types
                .boolean => |boolean| try writer.print("{}", .{boolean}),
                .number => |number| try writer.print("{d}", .{number}),
                .string => |string| try writer.writeAll(string),

                // Variables
                .let => |let| {
                    // Write name and parameters
                    try writer.print("const {s} = ", .{let.name});
                    try generate(self, &.{let.value.*});
                    try writer.writeAll(";");
                },

                // Function call
                .function_call => |function_call| {
                    // If name is special, translate it
                    if (std.mem.eql(u8, function_call.name, "print")) {
                        try writer.writeAll("try std.io.getStdOut().writer().print(\"{any}\\n\", .{ ");
                    } else {
                        try writer.print("{s}(", .{function_call.name});
                    }
                    for (function_call.arguments) |argument|
                        try generate(self, &.{argument});
                    if (std.mem.eql(u8, function_call.name, "print"))
                        try writer.writeAll(" }");
                    try writer.writeAll(");");
                },

                // Function declaration
                .function_decl => |function_decl| {
                    // Write function declaration
                    if (std.mem.eql(u8, function_decl.name, "main"))
                        try writer.writeAll("pub ");
                    try writer.print("fn {s}(", .{function_decl.name});
                    for (function_decl.parameters) |parameter|
                        try generate(self, &.{parameter});
                    try writer.writeAll(") !void {\n");

                    // Indend body
                    for (function_decl.body) |body| {
                        try writer.writeAll("    ");
                        try generate(self, &.{body});
                        try writer.writeAll("\n");
                    }
                    try writer.writeAll("}\n");
                },
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
    const code = try codegen(alloc, ast.items);
    try writer.writeAll(code);
    try writer.print("\n", .{});
}
