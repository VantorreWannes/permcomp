const std = @import("std");
const permutations = @import("permutations.zig");

pub const CombinationsTable = @import("combinations.zig");
pub const encode = permutations.encode;
pub const decode = permutations.decode;

test {
    _ = permutations;
    _ = CombinationsTable;
}