const std = @import("std");
const big = std.math.big;
const CombinationsTable = @import("combinations.zig");

/// Encodes a bitset (slice of booleans) into a unique integer rank using combinadics.
/// The rank represents the lexicographical index of the permutation of set bits.
///
/// * `allocator`: The allocator for the resulting big integer rank.
/// * `table`: A pre-computed `CombinationsTable`. `table.max_n` must be >= `bits.len`.
/// * `bits`: The input bitset to encode.
/// * `k`: The number of `true` values (set bits) in `bits`. This is passed for efficiency.
/// Returns a `std.math.big.int.Managed` representing the rank. Can fail on allocation.
pub fn encode(allocator: std.mem.Allocator, table: *const CombinationsTable, bits: []const bool, k: usize) !big.int.Managed {
    var rank = try big.int.Managed.init(allocator);
    errdefer rank.deinit();

    var n_remaining = bits.len;
    var k_remaining = k;

    for (bits) |bit| {
        if (k_remaining == 0 or k_remaining > n_remaining) break;

        if (bit) {
            k_remaining -= 1;
        } else {
            const combinations_to_skip = table.get(n_remaining - 1, k_remaining - 1).?;
            try rank.add(&rank, &combinations_to_skip);
        }
        n_remaining -= 1;
    }

    return rank;
}

/// Decodes a combinadic rank back into its corresponding bitset.
/// This is the inverse operation of `encode`.
///
/// * `allocator`: The allocator for the resulting boolean slice.
/// * `table`: A pre-computed `CombinationsTable`. `table.max_n` must be >= `n`.
/// * `rank`: The integer rank to decode.
/// * `n`: The length of the target bitset.
/// * `k`: The number of `true` values (set bits) the target bitset should have.
/// Returns a slice of booleans representing the decoded bitset. Can fail on allocation.
pub fn decode(
    allocator: std.mem.Allocator,
    table: *const CombinationsTable,
    rank: *const big.int.Managed,
    n: usize,
    k: usize,
) ![]bool {
    const result = try allocator.alloc(bool, n);
    errdefer allocator.free(result);

    var current_rank = try rank.clone();
    defer current_rank.deinit();

    var n_rem = n;
    var k_rem = k;

    for (0..n) |i| {
        if (k_rem == 0) {
            result[i] = false;
            n_rem -= 1;
            continue;
        }

        if (k_rem == n_rem) {
            result[i] = true;
            k_rem -= 1;
            n_rem -= 1;
            continue;
        }

        const combinations_with_one_at_start = table.get(n_rem - 1, k_rem - 1).?;
        if (current_rank.order(combinations_with_one_at_start) == .lt) {
            result[i] = true;
            k_rem -= 1;
        } else {
            result[i] = false;
            try current_rank.sub(&current_rank, &combinations_with_one_at_start);
        }
        n_rem -= 1;
    }

    return result;
}

test encode {
    const allocator = std.testing.allocator;
    var table = try CombinationsTable.init(allocator, 100);
    defer table.deinit();

    const bits = &[_]bool{ false, true, true, false };
    const one_bits_count = 2;

    var encoded = try encode(allocator, &table, bits, one_bits_count);
    defer encoded.deinit();

    var expected = try big.int.Managed.init(allocator);
    defer expected.deinit();
    try expected.set(3);

    try std.testing.expect(encoded.eql(expected));
}

test decode {
    const allocator = std.testing.allocator;
    var table = try CombinationsTable.init(allocator, 100);
    defer table.deinit();

    var encoded = try big.int.Managed.init(allocator);
    defer encoded.deinit();
    try encoded.set(3);

    const bits_count = 4;
    const one_bits_count = 2;

    const bits = try decode(allocator, &table, &encoded, bits_count, one_bits_count);
    defer allocator.free(bits);

    const expected = &[_]bool{ false, true, true, false };

    try std.testing.expectEqualSlices(bool, expected, bits);
}
