const std = @import("std");

// const GraphemeIterator = @import("ziglyph").GraphemeIterator;
// const Data = @import("grapheme").Data;
// const GraphemeIterator = @import("grapheme").Iterator;

// const codePointWidth = @import("ziglyph").display_width.codePointWidth;
// const strWidth = @import("ziglyph").display_width.strWidth;
// const Data = @import("display_width").Data;
// const codePointWidth = @import("display_width").codePointWidth;
// const strWidth = @import("display_width").strWidth;

// const CodePointIterator = @import("ziglyph").CodePointIterator;
// const CodePointIterator = @import("code_point").Iterator;

// const ascii = @import("ascii");
// const ascii = std.ascii;

// const norm = @import("ziglyph").Normalizer;
const Data = @import("Normalizer").Data;
const norm = @import("Normalizer");

pub fn main() !void {
    var args_iter = std.process.args();
    _ = args_iter.skip();
    const in_path = args_iter.next() orelse return error.MissingArg;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = try std.fs.cwd().readFileAlloc(allocator, in_path, std.math.maxInt(u32));
    defer allocator.free(input);

    var data = try Data.init(allocator);
    defer data.deinit();

    var n = try norm.init(allocator, &data);
    defer n.deinit();
    // var n = try norm.init(allocator);
    // defer n.deinit();

    // var iter = GraphemeIterator.init(input, &data);
    // defer iter.deinit();
    // var iter = CodePointIterator{ .bytes = input };
    var iter = std.mem.splitScalar(u8, input, '\n');

    var result: usize = 0;
    // var result: isize = 0;
    var timer = try std.time.Timer.start();

    // while (iter.next()) |cp| result += codePointWidth(@intCast(cp.code));
    // while (iter.next()) |_| result += 1;
    // while (iter.next()) |line| result += strWidth(line, &data);
    while (iter.next()) |line| {
        var nfc = try n.nfc(allocator, line);
        result += nfc.slice.len;
        nfc.deinit();
    }

    std.debug.print("result: {}, took: {}\n", .{ result, timer.lap() / std.time.ns_per_ms });
}
