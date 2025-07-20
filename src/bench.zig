const std = @import("std");
const zbench = @import("zbench");
const permutations = @import("permutations.zig");
const CombinationsTable = @import("combinations.zig");

fn randomBitArray(random: *std.Random, comptime length: comptime_int, comptime one_bits_count: comptime_int) [length]bool {
    const one_bits = [_]bool{true} ** one_bits_count;
    const zero_bits = [_]bool{false} ** (length - one_bits_count);
    var combined = one_bits ++ zero_bits;
    random.shuffle(bool, &combined);
    return combined;
}

fn PermutationEncodeBenchmark(comptime length: comptime_int, comptime one_bits_count: comptime_int) type {
    return struct {
        input: [length]bool,
        one_bits_count: usize,
        combinations_table: CombinationsTable,

        fn init(random: *std.Random, combinations_table: CombinationsTable) @This() {
            return .{
                .input = randomBitArray(random, length, one_bits_count),
                .one_bits_count = one_bits_count,
                .combinations_table = combinations_table,
            };
        }

        pub fn run(self: @This(), _: std.mem.Allocator) void {
            const allocator = std.heap.smp_allocator;
            var encoder = permutations.encode(allocator, &self.combinations_table, &self.input, self.one_bits_count) catch unreachable;
            defer encoder.deinit();
        }
    };
}

pub fn main() !void {
    var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
    var random = prng.random();

    const stdout = std.io.getStdOut().writer();

    const allocator = std.heap.smp_allocator;

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    var combinations_table = try CombinationsTable.init(allocator, 250);
    defer combinations_table.deinit();

    const lengths = [_]comptime_int{ 10, 100, 250 };
    const one_bits_count_factors = [_]comptime_int{ 1, 2, 5, 10 };

    inline for (lengths) |length| {
        inline for (one_bits_count_factors) |one_bits_count_factor| {
            const one_bits_count = length / one_bits_count_factor;
            const name = std.fmt.comptimePrint(
                "encoder_L{d}_O{d}",
                .{ length, one_bits_count },
            );
            const benchmark = PermutationEncodeBenchmark(length, one_bits_count).init(&random, combinations_table);
            try bench.addParam(name, &benchmark, .{ .time_budget_ns = 20_000_000 * length });
        }
    }

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
