const std = @import("std");

const display_width = @import("ziglyph").display_width;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    _ = args_iter.skip();
    const in_path = args_iter.next() orelse return error.MissingArg;

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
        const width = try display_width.strWidth(line, .half);
        result += width;
    }
    std.debug.print("Ziglyph display_width.strWidth: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap() / std.time.ns_per_ms) });
}
