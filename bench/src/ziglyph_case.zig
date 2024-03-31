const std = @import("std");

const ziglyph = @import("ziglyph");

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

    var iter = std.mem.splitScalar(u8, input, '\n');
    var result: usize = 0;
    var timer = try std.time.Timer.start();

    while (iter.next()) |line| {
        const upper = try ziglyph.toUpperStr(allocator, line);
        const lower = try ziglyph.toLowerStr(allocator, line);
        result += upper.len + lower.len;
    }
    std.debug.print("Ziglyph toUpperStr/toLowerStr: result: {}, took: {}\n", .{ result, timer.lap() / std.time.ns_per_ms });

    result = 0;
    iter.reset();
    timer.reset();

    while (iter.next()) |line| {
        if (ziglyph.isUpperStr(line)) result += 1;
        if (ziglyph.isLowerStr(line)) result += 2;
    }
    std.debug.print("Ziglyph isUpperStr/isLowerStr: result: {}, took: {}\n", .{ result, timer.lap() / std.time.ns_per_ms });
}
