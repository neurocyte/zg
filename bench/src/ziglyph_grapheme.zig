const std = @import("std");

const GraphemeIterator = @import("ziglyph").GraphemeIterator;

pub fn main() !void {
    var args_iter = std.process.args();
    _ = args_iter.skip();
    const in_path = args_iter.next() orelse return error.MissingArg;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input = try std.fs.cwd().readFileAlloc(
        allocator,
        in_path,
        std.math.maxInt(u32),
    );
    defer allocator.free(input);

    var iter = GraphemeIterator.init(input);
    var result: usize = 0;
    var timer = try std.time.Timer.start();

    while (iter.next()) |_| result += 1;
    std.debug.print("Ziglyph GraphemeIterator: result: {}, took: {}\n", .{ result, timer.lap() / std.time.ns_per_ms });
}
