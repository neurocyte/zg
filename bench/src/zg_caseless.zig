const std = @import("std");

const CaseFold = @import("CaseFold");
const Normalize = @import("Normalize");

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

    const fold_data = try CaseFold.FoldData.init(allocator);
    var case_fold = CaseFold{ .fold_data = &fold_data };
    var norm_data: Normalize.NormData = undefined;
    try Normalize.NormData.init(&norm_data, allocator);
    var normalize = Normalize{ .norm_data = &norm_data };

    var iter = std.mem.splitScalar(u8, input, '\n');
    var result: usize = 0;
    var buf: [256]u8 = [_]u8{'z'} ** 256;
    var prev_line: []const u8 = buf[0..1];
    var timer = try std.time.Timer.start();

    while (iter.next()) |line| {
        if (try case_fold.compatCaselessMatch(
            allocator,
            &normalize,
            prev_line,
            line,
        )) result += 1;
        @memcpy(buf[0..line.len], line);
        prev_line = buf[0..line.len];
    }
    std.debug.print("zg CaseFold.compatCaselessMatch: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap() / std.time.ns_per_ms) });

    result = 0;
    iter.reset();
    timer.reset();

    while (iter.next()) |line| {
        if (try case_fold.canonCaselessMatch(
            allocator,
            &normalize,
            prev_line,
            line,
        )) result += 1;
        @memcpy(buf[0..line.len], line);
        prev_line = buf[0..line.len];
    }
    std.debug.print("zg CaseFold.canonCaselessMatch: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap() / std.time.ns_per_ms) });
}
