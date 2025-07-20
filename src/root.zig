//! Permutation Compression using combinadics.
//! This library provides functions to encode and decode a bitset into a unique integer (rank).
//! This is a form of compression useful when the number of set bits is small compared to the total size of the bitset.

const std = @import("std");
const testing = std.testing;
const permutations = @import("permutations.zig");

pub const CombinationsTable = @import("combinations.zig");
pub const encode = permutations.encode;
pub const decode = permutations.decode;

test {
    _ = permutations;
    _ = CombinationsTable;
}

test "fuzz encode and decode" {
    const Context = struct {
        fn testOne(_: @This(), input: []const u8) anyerror!void {
            const allocator = testing.allocator;

            var bits = try allocator.alloc(bool, input.len);
            defer allocator.free(bits);

            var k: usize = 0;
            for (input, 0..) |byte, i| {
                bits[i] = (byte & 1) == 1;
                if (bits[i]) {
                    k += 1;
                }
            }

            var table = try CombinationsTable.init(allocator, bits.len);
            defer table.deinit();

            var encoded = try encode(allocator, &table, bits, k);
            defer encoded.deinit();

            const decoded = try decode(allocator, &table, &encoded, bits.len, k);
            defer allocator.free(decoded);

            try std.testing.expectEqualSlices(bool, bits, decoded);
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
