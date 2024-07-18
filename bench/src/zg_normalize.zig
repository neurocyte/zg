const std = @import("std");

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

    var norm_data: Normalize.NormData = undefined;
    try Normalize.NormData.init(&norm_data, allocator);
    const normalize = Normalize{ .norm_data = &norm_data };

    var iter = std.mem.splitScalar(u8, input, '\n');
    var result: usize = 0;
    var timer = try std.time.Timer.start();

    while (iter.next()) |line| {
        const nfkc = try normalize.nfkc(allocator, line);
        result += nfkc.slice.len;
    }
    std.debug.print("zg Normalize.nfkc: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });

    result = 0;
    iter.reset();
    timer.reset();

    while (iter.next()) |line| {
        const nfc = try normalize.nfc(allocator, line);
        result += nfc.slice.len;
    }
    std.debug.print("zg Normalize.nfc: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });

    result = 0;
    iter.reset();
    timer.reset();

    while (iter.next()) |line| {
        const nfkd = try normalize.nfkd(allocator, line);
        result += nfkd.slice.len;
    }
    std.debug.print("zg Normalize.nfkd: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });

    result = 0;
    iter.reset();
    timer.reset();

    while (iter.next()) |line| {
        const nfd = try normalize.nfd(allocator, line);
        result += nfd.slice.len;
    }
    std.debug.print("zg Normalize.nfd: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });

    result = 0;
    iter.reset();
    var buf: [256]u8 = [_]u8{'z'} ** 256;
    var prev_line: []const u8 = buf[0..1];
    timer.reset();

    while (iter.next()) |line| {
        if (try normalize.eql(allocator, prev_line, line)) result += 1;
        @memcpy(buf[0..line.len], line);
        prev_line = buf[0..line.len];
    }
    std.debug.print("Zg Normalize.eql: result: {}, took: {}\n", .{ result, std.fmt.fmtDuration(timer.lap()) });
}
