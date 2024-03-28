const std = @import("std");
const mem = std.mem;
const unicode = std.unicode;

const CodePoint = @import("code_point").CodePoint;
const CodePointIterator = @import("code_point").Iterator;
pub const GraphemeData = @import("GraphemeData");

/// `Grapheme` represents a Unicode grapheme cluster by its length and offset in the source bytes.
pub const Grapheme = struct {
    len: u8,
    offset: u32,

    /// `bytes` returns the slice of bytes that correspond to
    /// this grapheme cluster in `src`.
    pub fn bytes(self: Grapheme, src: []const u8) []const u8 {
        return src[self.offset..][0..self.len];
    }
};

/// `Iterator` iterates a sting of UTF-8 encoded bytes one grapheme cluster at-a-time.
pub const Iterator = struct {
    buf: [2]?CodePoint = .{ null, null },
    cp_iter: CodePointIterator,
    data: *const GraphemeData,

    const Self = @This();

    /// Assumes `src` is valid UTF-8.
    pub fn init(str: []const u8, data: *const GraphemeData) Self {
        var self = Self{ .cp_iter = .{ .bytes = str }, .data = data };
        self.advance();
        return self;
    }

    fn advance(self: *Self) void {
        self.buf[0] = self.buf[1];
        self.buf[1] = self.cp_iter.next();
    }

    pub fn next(self: *Self) ?Grapheme {
        self.advance();

        // If no more
        if (self.buf[0] == null) return null;
        // If last one
        if (self.buf[1] == null) return Grapheme{ .len = self.buf[0].?.len, .offset = self.buf[0].?.offset };
        // If ASCII
        if (self.buf[0].?.code != '\r' and self.buf[0].?.code < 128 and self.buf[1].?.code < 128) {
            return Grapheme{ .len = self.buf[0].?.len, .offset = self.buf[0].?.offset };
        }

        const gc_start = self.buf[0].?.offset;
        var gc_len: u8 = self.buf[0].?.len;
        var state = State{};

        if (graphemeBreak(
            self.buf[0].?.code,
            self.buf[1].?.code,
            self.data,
            &state,
        )) return Grapheme{ .len = gc_len, .offset = gc_start };

        while (true) {
            self.advance();
            if (self.buf[0] == null) break;

            gc_len += self.buf[0].?.len;

            if (graphemeBreak(
                self.buf[0].?.code,
                if (self.buf[1]) |ncp| ncp.code else 0,
                self.data,
                &state,
            )) break;
        }

        return Grapheme{ .len = gc_len, .offset = gc_start };
    }
};

// Predicates
fn isBreaker(cp: u21, data: *const GraphemeData) bool {
    // Extract relevant properties.
    const cp_gbp_prop = data.gbp(cp);
    return cp == '\x0d' or cp == '\x0a' or cp_gbp_prop == .Control;
}

// Grapheme break state.
const State = struct {
    bits: u3 = 0,

    // Extended Pictographic (emoji)
    fn hasXpic(self: State) bool {
        return self.bits & 1 == 1;
    }
    fn setXpic(self: *State) void {
        self.bits |= 1;
    }
    fn unsetXpic(self: *State) void {
        self.bits ^= 1;
    }

    // Regional Indicatior (flags)
    fn hasRegional(self: State) bool {
        return self.bits & 2 == 2;
    }
    fn setRegional(self: *State) void {
        self.bits |= 2;
    }
    fn unsetRegional(self: *State) void {
        self.bits ^= 2;
    }

    // Indic Conjunct
    fn hasIndic(self: State) bool {
        return self.bits & 4 == 4;
    }
    fn setIndic(self: *State) void {
        self.bits |= 4;
    }
    fn unsetIndic(self: *State) void {
        self.bits ^= 4;
    }
};

/// `graphemeBreak` returns true only if a grapheme break point is required
/// between `cp1` and `cp2`. `state` should start out as 0. If calling
/// iteratively over a sequence of code points, this function must be called
/// IN ORDER on ALL potential breaks in a string.
/// Modeled after the API of utf8proc's `utf8proc_grapheme_break_stateful`.
/// https://github.com/JuliaStrings/utf8proc/blob/2bbb1ba932f727aad1fab14fafdbc89ff9dc4604/utf8proc.h#L599-L617
pub fn graphemeBreak(
    cp1: u21,
    cp2: u21,
    data: *const GraphemeData,
    state: *State,
) bool {
    // Extract relevant properties.
    const cp1_gbp_prop = data.gbp(cp1);
    const cp1_indic_prop = data.indic(cp1);
    const cp1_is_emoji = data.isEmoji(cp1);

    const cp2_gbp_prop = data.gbp(cp2);
    const cp2_indic_prop = data.indic(cp2);
    const cp2_is_emoji = data.isEmoji(cp2);

    // GB11: Emoji Extend* ZWJ x Emoji
    if (!state.hasXpic() and cp1_is_emoji) state.setXpic();
    // GB9c: Indic Conjunct Break
    if (!state.hasIndic() and cp1_indic_prop == .Consonant) state.setIndic();

    // GB3: CR x LF
    if (cp1 == '\r' and cp2 == '\n') return false;

    // GB4: Control
    if (isBreaker(cp1, data)) return true;

    // GB11: Emoji Extend* ZWJ x Emoji
    if (state.hasXpic() and
        cp1_gbp_prop == .ZWJ and
        cp2_is_emoji)
    {
        state.unsetXpic();
        return false;
    }

    // GB9b: x (Extend | ZWJ)
    if (cp2_gbp_prop == .Extend or cp2_gbp_prop == .ZWJ) return false;

    // GB9a: x Spacing
    if (cp2_gbp_prop == .SpacingMark) return false;

    // GB9b: Prepend x
    if (cp1_gbp_prop == .Prepend and !isBreaker(cp2, data)) return false;

    // GB12, GB13: RI x RI
    if (cp1_gbp_prop == .Regional_Indicator and cp2_gbp_prop == .Regional_Indicator) {
        if (state.hasRegional()) {
            state.unsetRegional();
            return true;
        } else {
            state.setRegional();
            return false;
        }
    }

    // GB6: Hangul L x (L|V|LV|VT)
    if (cp1_gbp_prop == .L) {
        if (cp2_gbp_prop == .L or
            cp2_gbp_prop == .V or
            cp2_gbp_prop == .LV or
            cp2_gbp_prop == .LVT) return false;
    }

    // GB7: Hangul (LV | V) x (V | T)
    if (cp1_gbp_prop == .LV or cp1_gbp_prop == .V) {
        if (cp2_gbp_prop == .V or
            cp2_gbp_prop == .T) return false;
    }

    // GB8: Hangul (LVT | T) x T
    if (cp1_gbp_prop == .LVT or cp1_gbp_prop == .T) {
        if (cp2_gbp_prop == .T) return false;
    }

    // GB9c: Indic Conjunct Break
    if (state.hasIndic() and
        cp1_indic_prop == .Consonant and
        (cp2_indic_prop == .Extend or cp2_indic_prop == .Linker))
    {
        return false;
    }

    if (state.hasIndic() and
        cp1_indic_prop == .Extend and
        cp2_indic_prop == .Linker)
    {
        return false;
    }

    if (state.hasIndic() and
        (cp1_indic_prop == .Linker or cp1_gbp_prop == .ZWJ) and
        cp2_indic_prop == .Consonant)
    {
        state.unsetIndic();
        return false;
    }

    return true;
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
        var iter = Iterator.init(all_bytes.items, &data);

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

test "Segmentation ZWJ and ZWSP emoji sequences" {
    const seq_1 = "\u{1F43B}\u{200D}\u{2744}\u{FE0F}";
    const seq_2 = "\u{1F43B}\u{200D}\u{2744}\u{FE0F}";
    const with_zwj = seq_1 ++ "\u{200D}" ++ seq_2;
    const with_zwsp = seq_1 ++ "\u{200B}" ++ seq_2;
    const no_joiner = seq_1 ++ seq_2;

    const data = try GraphemeData.init(std.testing.allocator);
    defer data.deinit();

    var iter = Iterator.init(with_zwj, &data);

    var i: usize = 0;
    while (iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 1), i);

    iter = Iterator.init(with_zwsp, &data);
    i = 0;
    while (iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 3), i);

    iter = Iterator.init(no_joiner, &data);
    i = 0;
    while (iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 2), i);
}
