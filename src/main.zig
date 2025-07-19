const std = @import("std");
const permcomp = @import("permcomp");

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
