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

    // Write file to tmp
    const dir = "/tmp";
    const name = "main.zig";
    const tmp = try std.fs.openDirAbsolute(dir, .{});
    try tmp.writeFile(.{
        .sub_path = name,
        .data = output,
    });

    // Execute with Zig
    const result = try std.process.Child.run(.{
        .cwd = dir,
        .allocator = alloc,
        .argv = &.{ "zig", "run", name },
    });

    // Display in terminal
    if (result.stdout.len > 0) {
        const stdout = std.io.getStdOut().writer();
        try stdout.writeAll(result.stdout);
    } else {
        const stderr = std.io.getStdOut().writer();
        try stderr.writeAll(output);
        try stderr.writeAll(result.stderr);
    }
}
