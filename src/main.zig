const std = @import("std");

// const GraphemeIterator = @import("ziglyph").GraphemeIterator;
const GraphemeIterator = @import("Grapheme.zig").GraphemeIterator;
const input = @embedFile("lang_mix.txt");

pub fn main() !void {
    var result: usize = 0;
    var iter = GraphemeIterator.init(input);

    var timer = try std.time.Timer.start();

    for (0..50) |_| {
        while (iter.next()) |_| result += 1;
        iter.cp_iter.i = 0;
    }

    std.debug.print("result: {}, took: {}\n", .{ result, timer.lap() / std.time.ns_per_ms });
}

test {
    _ = @import("trie.zig");
}
