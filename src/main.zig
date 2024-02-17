const std = @import("std");

// const GraphemeIterator = @import("ziglyph").GraphemeIterator;
// const GraphemeIterator = @import("Grapheme").GraphemeIterator;
// const codePointWidth = @import("ziglyph").display_width.codePointWidth;
// const codePointWidth = @import("display_width").codePointWidth;
// const strWidth = @import("ziglyph").display_width.strWidth;
const strWidth = @import("display_width").strWidth;
// const CodePointIterator = @import("CodePoint").CodePointIterator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = try std.fs.cwd().readFileAlloc(allocator, "lang_mix.txt", std.math.maxInt(u32));
    defer allocator.free(input);

    // var iter = GraphemeIterator.init(input);
    // var iter = CodePointIterator{ .bytes = input };
    var iter = std.mem.splitScalar(u8, input, '\n');

    var result: usize = 0;
    // var result: isize = 0;
    var timer = try std.time.Timer.start();

    // for (0..50) |_| {
    // while (iter.next()) |cp| result += codePointWidth(@intCast(cp.code));
    // while (iter.next()) |_| result += 1;
    while (iter.next()) |line| result += strWidth(line);
    // iter.cp_iter.i = 0;
    // }

    std.debug.print("result: {}, took: {}\n", .{ result, timer.lap() / std.time.ns_per_ms });
}
