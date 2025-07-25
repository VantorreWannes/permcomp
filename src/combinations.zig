const std = @import("std");
const big = std.math.big;

/// A pre-computed table of binomial coefficients (nCk), also known as "combinations".
/// This is used to speed up the encoding and decoding process by providing fast lookups
/// for the number of combinations of `n` items taken `k` at a time.
/// The table is stored in a flat array, and the index for a given (n, k) is calculated as `n * (n + 1) / 2 + k`.
const CombinationsTable = @This();

allocator: std.mem.Allocator,
max_n: usize,
table: []big.int.Managed,

/// Initializes a new CombinationsTable, pre-calculating all combinations up to `max_n`.
/// The table uses `std.math.big.int` to handle large combination values.
///
/// * `allocator`: The allocator to use for the table and its big integer entries.
/// * `max_n`: The maximum value of `n` for which combinations will be calculated and stored.
/// Returns an initialized `CombinationsTable`. Can fail if allocation fails.
pub fn init(allocator: std.mem.Allocator, max_n: usize) !CombinationsTable {
    const table_size = (max_n + 1) * (max_n + 2) / 2;
    const table = try allocator.alloc(big.int.Managed, table_size);
    errdefer deinitTable(table, allocator);

    for (table) |*entry| {
        entry.* = try big.int.Managed.init(allocator);
    }

    var zero = try big.int.Managed.init(allocator);
    defer zero.deinit();

    var base_value = getPtrNC(table, 0, 0).?;
    try base_value.set(1);

    var n: usize = 1;
    while (n <= max_n) : (n += 1) {
        var current_value = getPtrNC(table, n, 0).?;
        try current_value.set(1);
        var k: usize = 1;
        while (k <= n) : (k += 1) {
            const c_n1_k1 = getPtrNC(table, n - 1, k - 1) orelse zero;
            const c_n1_k = getPtrNC(table, n - 1, k) orelse zero;
            var value = getPtrNC(table, n, k).?;
            try value.add(&c_n1_k1, &c_n1_k);
        }
    }

    return CombinationsTable{
        .allocator = allocator,
        .max_n = max_n,
        .table = table,
    };
}

fn getPtrNC(table: []big.int.Managed, n: usize, k: usize) ?big.int.Managed {
    if (k > n) {
        return null;
    }
    const index = n * (n + 1) / 2 + k;
    return table[index];
}

fn deinitTable(table: []big.int.Managed, allocator: std.mem.Allocator) void {
    for (table) |*entry| {
        entry.deinit();
    }
    allocator.free(table);
}

/// Deinitializes the CombinationsTable, freeing all allocated memory for the table and its entries.
pub fn deinit(self: *CombinationsTable) void {
    deinitTable(self.table, self.allocator);
}

/// Retrieves the pre-calculated value of "n choose k" (nCk) from the table.
///
/// * `n`: The total number of items.
/// * `k`: The number of items to choose.
/// Returns the managed big integer representing the result, or `null` if `n` or `k` are out of bounds
/// (k > n or n > max_n).
pub fn get(self: *const CombinationsTable, n: usize, k: usize) ?big.int.Managed {
    if (k > n or n > self.max_n) {
        return null;
    }
    const index = n * (n + 1) / 2 + k;
    return self.table[index];
}

test get {
    const allocator = std.testing.allocator;
    const max_n = 20;
    var table = try CombinationsTable.init(allocator, max_n);
    defer table.deinit();

    var expected = try big.int.Managed.init(allocator);
    defer expected.deinit();
    try expected.set(252);

    try std.testing.expect(table.get(10, 5).?.eql(expected));
    try expected.set(184756);
    try std.testing.expect(table.get(20, 10).?.eql(expected));

    try expected.set(1);
    for (0..max_n + 1) |n| {
        try std.testing.expect(table.get(n, 0).?.eql(expected));
        try std.testing.expect(table.get(n, n).?.eql(expected));
    }

    try std.testing.expectEqual(table.get(10, 11), null);
    try std.testing.expectEqual(table.get(21, 5), null);
}
