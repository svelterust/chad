const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const codegen = @import("codegen.zig");

pub fn main() !void {
    // Allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Get file
    var arguments = std.process.args();
    _ = arguments.skip();
    const file = arguments.next() orelse return error.NoFileSpecified;

    // Read and process file
    const src = try std.fs.cwd().readFileAlloc(alloc, file, std.math.maxInt(usize));
    const tokens = try lexer.lex(alloc, src);
    const ast = try parser.parse(alloc, tokens.items);
    const output = try codegen.codegen(alloc, ast.items);

    // Print file
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}", .{output});
}
