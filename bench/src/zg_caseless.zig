const std = @import("std");

const CaseFolding = @import("CaseFolding");

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

    const case_fold = try CaseFolding.init(allocator);

    var iter = std.mem.splitScalar(u8, input, '\n');
    var result: usize = 0;
    var buf: [256]u8 = [_]u8{'z'} ** 256;
    var prev_line: []const u8 = buf[0..1];
    var timer = try std.time.Timer.start();

    while (iter.next()) |line| {
        if (try case_fold.compatCaselessMatch(
            allocator,
            prev_line,
            line,
        )) result += 1;
        @memcpy(buf[0..line.len], line);
        prev_line = buf[0..line.len];
    }
    std.debug.print("zg CaseFolding.compatCaselessMatch: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });

    result = 0;
    iter.reset();
    timer.reset();

    while (iter.next()) |line| {
        if (try case_fold.canonCaselessMatch(
            allocator,
            prev_line,
            line,
        )) result += 1;
        @memcpy(buf[0..line.len], line);
        prev_line = buf[0..line.len];
    }
    std.debug.print("zg CaseFolding.canonCaselessMatch: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });
}
