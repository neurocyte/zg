const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const io = std.io;
const heap = std.heap;
const mem = std.mem;
const testing = std.testing;
const unicode = std.unicode;

const Grapheme = @import("grapheme").Grapheme;
const GraphemeData = @import("grapheme").GraphemeData;
const GraphemeIterator = @import("grapheme").Iterator;
const Normalize = @import("Normalize");

test "Unicode normalization tests" {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const data = try Normalize.NormData.init(allocator);
    const n = Normalize{ .norm_data = &data };

    var file = try fs.cwd().openFile("data/unicode/NormalizationTest.txt", .{});
    defer file.close();
    var buf_reader = io.bufferedReader(file.reader());
    const input_stream = buf_reader.reader();

    var line_no: usize = 0;
    var buf: [4096]u8 = undefined;
    var cp_buf: [4]u8 = undefined;

    while (try input_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        line_no += 1;
        // Skip comments or empty lines.
        if (line.len == 0 or line[0] == '#' or line[0] == '@') continue;
        // Iterate over fields.
        var fields = mem.split(u8, line, ";");
        var field_index: usize = 0;
        var input: []u8 = undefined;
        defer allocator.free(input);

        while (fields.next()) |field| : (field_index += 1) {
            if (field_index == 0) {
                var i_buf = std.ArrayList(u8).init(allocator);
                defer i_buf.deinit();

                var i_fields = mem.split(u8, field, " ");
                while (i_fields.next()) |s| {
                    const icp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(icp, &cp_buf);
                    try i_buf.appendSlice(cp_buf[0..len]);
                }

                input = try i_buf.toOwnedSlice();
            } else if (field_index == 1) {
                //debug.print("\n*** {s} ***\n", .{line});
                // NFC, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = mem.split(u8, field, " ");
                while (w_fields.next()) |s| {
                    const wcp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfc(allocator, input);
                defer got.deinit();

                try testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 2) {
                // NFD, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = mem.split(u8, field, " ");
                while (w_fields.next()) |s| {
                    const wcp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfd(allocator, input);
                defer got.deinit();

                try testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 3) {
                // NFKC, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = mem.split(u8, field, " ");
                while (w_fields.next()) |s| {
                    const wcp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfkc(allocator, input);
                defer got.deinit();

                try testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 4) {
                // NFKD, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = mem.split(u8, field, " ");
                while (w_fields.next()) |s| {
                    const wcp = try fmt.parseInt(u21, s, 16);
                    const len = try unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                const got = try n.nfkd(allocator, input);
                defer got.deinit();

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

    const data = try GraphemeData.init(allocator);
    defer data.deinit();

    var buf: [4096]u8 = undefined;
    var line_no: usize = 1;

    while (try input_stream.readUntilDelimiterOrEof(&buf, '\n')) |raw| : (line_no += 1) {
        // Skip comments or empty lines.
        if (raw.len == 0 or raw[0] == '#' or raw[0] == '@') continue;

        // Clean up.
        var line = std.mem.trimLeft(u8, raw, "÷ ");
        if (std.mem.indexOf(u8, line, " ÷\t#")) |octo| {
            line = line[0..octo];
        }
        // Iterate over fields.
        var want = std.ArrayList(Grapheme).init(allocator);
        defer want.deinit();

        var all_bytes = std.ArrayList(u8).init(allocator);
        defer all_bytes.deinit();

        var graphemes = std.mem.split(u8, line, " ÷ ");
        var bytes_index: u32 = 0;

        while (graphemes.next()) |field| {
            var code_points = std.mem.split(u8, field, " ");
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

        // std.debug.print("\nline {}: {s}\n", .{ line_no, all_bytes.items });
        var iter = GraphemeIterator.init(all_bytes.items, &data);

        // Chaeck.
        for (want.items) |want_gc| {
            const got_gc = (iter.next()).?;
            try std.testing.expectEqualStrings(
                want_gc.bytes(all_bytes.items),
                got_gc.bytes(all_bytes.items),
            );
        }
    }
}
