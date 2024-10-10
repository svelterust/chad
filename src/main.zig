const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("lexer.zig");

pub fn main() !void {
    const file = @embedFile("examples/hello.chad");
    std.debug.print("{s}\n", .{file});
}
