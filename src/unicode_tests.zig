const dbg_print = false;

test "Unicode normalization tests" {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const n = try Normalize.init(allocator);
    defer n.deinit(allocator);

    var file = try fs.cwd().openFile("data/unicode/NormalizationTest.txt", .{});
    defer file.close();
    var buf_reader = io.bufferedReader(file.reader());
    var input_stream = buf_reader.reader();

    var buf: [4096]u8 = undefined;
    var cp_buf: [4]u8 = undefined;

    var line_iter: IterRead = .{ .read = &input_stream };

    while (try line_iter.next(&buf)) |line| {
        // Iterate over fields.
        var fields = mem.splitScalar(u8, line, ';');
        var field_index: usize = 0;
        var input: []u8 = undefined;
        defer allocator.free(input);

        while (fields.next()) |field| : (field_index += 1) {
            if (field_index == 0) {
                var i_buf = std.ArrayList(u8).init(allocator);
                defer i_buf.deinit();

                var i_fields = mem.splitScalar(u8, field, ' ');
                while (i_fields.next()) |s| {
                    const icp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(icp, &cp_buf);
                    try i_buf.appendSlice(cp_buf[0..len]);
                }

                input = try i_buf.toOwnedSlice();
            } else if (field_index == 1) {
                if (dbg_print) debug.print("\n*** {s} ***\n", .{line});
                // NFC, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = mem.splitScalar(u8, field, ' ');
                while (w_fields.next()) |s| {
                    const wcp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfc(allocator, input);
                defer got.deinit(allocator);

                try testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 2) {
                // NFD, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = mem.splitScalar(u8, field, ' ');
                while (w_fields.next()) |s| {
                    const wcp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfd(allocator, input);
                defer got.deinit(allocator);

                try testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 3) {
                // NFKC, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = mem.splitScalar(u8, field, ' ');
                while (w_fields.next()) |s| {
                    const wcp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfkc(allocator, input);
                defer got.deinit(allocator);

                try testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 4) {
                // NFKD, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = mem.splitScalar(u8, field, ' ');
                while (w_fields.next()) |s| {
                    const wcp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                const got = try n.nfkd(allocator, input);
                defer got.deinit(allocator);

                try testing.expectEqualStrings(want, got.slice);
            } else {
                continue;
            }
        }
    }
}

test "Segmentation GraphemeIterator" {
    const allocator = std.testing.allocator;
    var file = try std.fs.cwd().openFile("data/unicode/auxiliary/GraphemeBreakTest.txt", .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var input_stream = buf_reader.reader();

    const graph = try Graphemes.init(allocator);
    defer graph.deinit(allocator);

    var buf: [4096]u8 = undefined;
    var line_iter: IterRead = .{ .read = &input_stream };

    while (try line_iter.next(&buf)) |raw| {
        // Clean up.
        var line = std.mem.trimLeft(u8, raw, "÷ ");
        if (std.mem.indexOf(u8, line, " ÷\t")) |final| {
            line = line[0..final];
        }
        // Iterate over fields.
        var want = std.ArrayList(Grapheme).init(allocator);
        defer want.deinit();

        var all_bytes = std.ArrayList(u8).init(allocator);
        defer all_bytes.deinit();

        var graphemes = std.mem.splitSequence(u8, line, " ÷ ");
        var bytes_index: u32 = 0;

        while (graphemes.next()) |field| {
            var code_points = std.mem.splitScalar(u8, field, ' ');
            var cp_buf: [4]u8 = undefined;
            var cp_index: u32 = 0;
            var gc_len: u8 = 0;

            while (code_points.next()) |code_point| {
                if (std.mem.eql(u8, code_point, "×")) continue;
                const cp: u21 = try std.fmt.parseInt(u21, code_point, 16);
                const len = try unicode.utf8Encode(cp, &cp_buf);
                try all_bytes.appendSlice(cp_buf[0..len]);
                cp_index += len;
                gc_len += len;
            }

            try want.append(Grapheme{ .len = gc_len, .offset = bytes_index });
            bytes_index += cp_index;
        }

        {
            var iter = graph.iterator(all_bytes.items);

            // Check.
            for (want.items) |want_gc| {
                const got_gc = (iter.next()).?;
                try std.testing.expectEqualStrings(
                    want_gc.bytes(all_bytes.items),
                    got_gc.bytes(all_bytes.items),
                );
            }
        }
        {
            var iter = graph.reverseIterator(all_bytes.items);

            // Check.
            var i: usize = want.items.len;
            while (i > 0) {
                i -= 1;
                const want_gc = want.items[i];
                const got_gc = iter.prev() orelse {
                    std.debug.print(
                        "line {d} grapheme {d}: expected {any} found null\n",
                        .{ line_iter.line, i, want_gc },
                    );
                    return error.TestExpectedEqual;
                };
                std.testing.expectEqualStrings(
                    want_gc.bytes(all_bytes.items),
                    got_gc.bytes(all_bytes.items),
                ) catch |err| {
                    std.debug.print(
                        "line {d} grapheme {d}: expected {any} found {any}\n",
                        .{ line_iter.line, i, want_gc, got_gc },
                    );
                    return err;
                };
            }
        }
    }
}

test "Segmentation Word Iterator" {
    const allocator = std.testing.allocator;
    var file = try std.fs.cwd().openFile("data/unicode/auxiliary/WordBreakTest.txt", .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var input_stream = buf_reader.reader();

    const wb = try Words.init(allocator);
    defer wb.deinit(allocator);

    var buf: [4096]u8 = undefined;
    var line_iter: IterRead = .{ .read = &input_stream };

    while (try line_iter.next(&buf)) |raw| {
        // Clean up.
        var line = std.mem.trimLeft(u8, raw, "÷ ");
        if (std.mem.indexOf(u8, line, " ÷\t")) |final| {
            line = line[0..final];
        }
        // Iterate over fields.
        var want = std.ArrayList(Word).init(allocator);
        defer want.deinit();

        var all_bytes = std.ArrayList(u8).init(allocator);
        defer all_bytes.deinit();

        var words = std.mem.splitSequence(u8, line, " ÷ ");
        var bytes_index: u32 = 0;

        while (words.next()) |field| {
            var code_points = std.mem.splitScalar(u8, field, ' ');
            var cp_buf: [4]u8 = undefined;
            var cp_index: u32 = 0;
            var gc_len: u8 = 0;

            while (code_points.next()) |code_point| {
                if (std.mem.eql(u8, code_point, "×")) continue;
                const cp: u21 = try std.fmt.parseInt(u21, code_point, 16);
                const len = try unicode.utf8Encode(cp, &cp_buf);
                try all_bytes.appendSlice(cp_buf[0..len]);
                cp_index += len;
                gc_len += len;
            }

            try want.append(Word{ .len = gc_len, .offset = bytes_index });
            bytes_index += cp_index;
        }
        const this_str = all_bytes.items;

        {
            var iter = wb.iterator(this_str);
            var peeked: ?Word = iter.peek();

            // Check.
            for (want.items, 1..) |want_word, idx| {
                const got_word = (iter.next()).?;
                std.testing.expectEqualStrings(
                    want_word.bytes(this_str),
                    got_word.bytes(this_str),
                ) catch |err| {
                    debug.print("Error on line {d}, #{d}\n", .{ line_iter.line, idx });
                    return err;
                };
                std.testing.expectEqualStrings(
                    peeked.?.bytes(this_str),
                    got_word.bytes(this_str),
                ) catch |err| {
                    debug.print("Peek != word on line {d} #{d}\n", .{ line_iter.line, idx });
                    return err;
                };
                var r_iter = iter.reverseIterator();
                const if_r_word = r_iter.prev();
                if (if_r_word) |r_word| {
                    std.testing.expectEqualStrings(
                        want_word.bytes(this_str),
                        r_word.bytes(this_str),
                    ) catch |err| {
                        debug.print("Reversal Error on line {d}, #{d}\n", .{ line_iter.line, idx });
                        return err;
                    };
                } else {
                    try testing.expect(false);
                }
                for (got_word.offset..got_word.offset + got_word.len) |i| {
                    const this_word = wb.wordAtIndex(this_str, i);
                    std.testing.expectEqualSlices(
                        u8,
                        got_word.bytes(this_str),
                        this_word.bytes(this_str),
                    ) catch |err| {
                        debug.print("Wrong word on line {d} #{d} offset {d}\n", .{ line_iter.line, idx + 1, i });
                        return err;
                    };
                }
                peeked = iter.peek();
            }
        }
        {
            var r_iter = wb.reverseIterator(this_str);
            var peeked: ?Word = r_iter.peek();
            var idx = want.items.len - 1;

            while (true) : (idx -= 1) {
                const want_word = want.items[idx];
                const got_word = r_iter.prev().?;
                std.testing.expectEqualSlices(
                    u8,
                    want_word.bytes(this_str),
                    got_word.bytes(this_str),
                ) catch |err| {
                    debug.print("Error on line {d}, #{d}\n", .{ line_iter.line, idx + 1 });
                    return err;
                };
                std.testing.expectEqualStrings(
                    peeked.?.bytes(this_str),
                    got_word.bytes(this_str),
                ) catch |err| {
                    debug.print("Peek != word on line {d} #{d}\n", .{ line_iter.line, idx + 1 });
                    return err;
                };
                var f_iter = r_iter.forwardIterator();
                const if_f_word = f_iter.next();
                if (if_f_word) |f_word| {
                    std.testing.expectEqualStrings(
                        want_word.bytes(this_str),
                        f_word.bytes(this_str),
                    ) catch |err| {
                        debug.print("Reversal Error on line {d}, #{d}\n", .{ line_iter.line, idx });
                        return err;
                    };
                } else {
                    try testing.expect(false);
                }
                for (got_word.offset..got_word.offset + got_word.len) |i| {
                    const this_word = wb.wordAtIndex(this_str, i);
                    std.testing.expectEqualSlices(
                        u8,
                        got_word.bytes(this_str),
                        this_word.bytes(this_str),
                    ) catch |err| {
                        debug.print("Wrong word on line {d} #{d} offset {d}\n", .{ line_iter.line, idx + 1, i });
                        return err;
                    };
                }
                peeked = r_iter.peek();
                if (idx == 0) break;
            }
        }
    }
}

const IterRead = struct {
    read: *Reader,
    line: usize = 0,

    pub fn next(iter: *IterRead, buf: []u8) !?[]const u8 {
        defer iter.line += 1;
        const maybe_line = try iter.read.readUntilDelimiterOrEof(buf, '#');
        if (maybe_line) |this_line| {
            try iter.read.skipUntilDelimiterOrEof('\n');
            if (this_line.len == 0 or this_line[0] == '@') {
                // comment, next line
                return iter.next(buf);
            } else {
                return this_line;
            }
        } else {
            return null;
        }
    }
};

const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const io = std.io;
const Reader = io.BufferedReader(4096, fs.File.Reader).Reader;
const heap = std.heap;
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const unicode = std.unicode;

const Grapheme = @import("Graphemes").Grapheme;
const Graphemes = @import("Graphemes");
const GraphemeIterator = @import("Graphemes").Iterator;
const Normalize = @import("Normalize");

const Words = @import("Words");
const Word = Words.Word;
