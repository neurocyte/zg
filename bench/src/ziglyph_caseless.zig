const std = @import("std");

const Normalizer = @import("ziglyph").Normalizer;

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

    var normalizer = try Normalizer.init(allocator);

    var iter = std.mem.splitScalar(u8, input, '\n');
    var result: usize = 0;
    var buf: [256]u8 = [_]u8{'z'} ** 256;
    var prev_line: []const u8 = buf[0..1];
    var timer = try std.time.Timer.start();

    while (iter.next()) |line| {
        if (try normalizer.eqlCaseless(allocator, prev_line, line)) result += 1;
        @memcpy(buf[0..line.len], line);
        prev_line = buf[0..line.len];
    }
    std.debug.print("Ziglyph Normalizer.eqlCaseless: result: {}, took: {}\n", .{ result, timer.lap() / std.time.ns_per_ms });
}
