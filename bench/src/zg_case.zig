const std = @import("std");

const LetterCasing = @import("LetterCasing");

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

    const case = try LetterCasing.init(allocator);

    var iter = std.mem.splitScalar(u8, input, '\n');
    var result: usize = 0;
    var timer = try std.time.Timer.start();

    while (iter.next()) |line| {
        const upper = try case.toUpperStr(allocator, line);
        const lower = try case.toLowerStr(allocator, line);
        result += upper.len + lower.len;
    }
    std.debug.print("zg toUpperStr/toLowerStr: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });

    result = 0;
    iter.reset();
    timer.reset();

    while (iter.next()) |line| {
        if (case.isUpperStr(line)) result += 1;
        if (case.isLowerStr(line)) result += 2;
    }
    std.debug.print("zg isUpperStr/isLowerStr: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });
}
