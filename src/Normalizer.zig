//! Normalizer contains functions and methods that implement
//! Unicode Normalization. You can normalize strings into NFC,
//! NFKC, NFD, and NFKD normalization forms.

const std = @import("std");
const testing = std.testing;

const ascii = @import("ascii");
const CodePointIterator = @import("code_point").Iterator;
pub const NormData = @import("NormData");

norm_data: *NormData,

const Self = @This();

const SBase: u21 = 0xAC00;
const LBase: u21 = 0x1100;
const VBase: u21 = 0x1161;
const TBase: u21 = 0x11A7;
const LCount: u21 = 19;
const VCount: u21 = 21;
const TCount: u21 = 28;
const NCount: u21 = 588; // VCount * TCount
const SCount: u21 = 11172; // LCount * NCount

fn decomposeHangul(self: Self, cp: u21, buf: []u21) ?Decomp {
    const kind = self.norm_data.hangul_data.syllable(cp);
    if (kind != .LV and kind != .LVT) return null;

    const SIndex: u21 = cp - SBase;
    const LIndex: u21 = SIndex / NCount;
    const VIndex: u21 = (SIndex % NCount) / TCount;
    const TIndex: u21 = SIndex % TCount;
    const LPart: u21 = LBase + LIndex;
    const VPart: u21 = VBase + VIndex;

    var dc = Decomp{ .form = .nfd };
    buf[0] = LPart;
    buf[1] = VPart;

    if (TIndex == 0) {
        dc.cps = buf[0..2];
        return dc;
    }

    // TPart
    buf[2] = TBase + TIndex;
    dc.cps = buf[0..3];
    return dc;
}

fn composeHangulCanon(lv: u21, t: u21) u21 {
    std.debug.assert(0x11A8 <= t and t <= 0x11C2);
    return lv + (t - TBase);
}

fn composeHangulFull(l: u21, v: u21, t: u21) u21 {
    std.debug.assert(0x1100 <= l and l <= 0x1112);
    std.debug.assert(0x1161 <= v and v <= 0x1175);
    const LIndex = l - LBase;
    const VIndex = v - VBase;
    const LVIndex = LIndex * NCount + VIndex * TCount;

    if (t == 0) return SBase + LVIndex;

    std.debug.assert(0x11A8 <= t and t <= 0x11C2);
    const TIndex = t - TBase;

    return SBase + LVIndex + TIndex;
}

const Form = enum {
    nfc,
    nfd,
    nfkc,
    nfkd,
    same,
};

const Decomp = struct {
    form: Form = .same,
    cps: []const u21 = &.{},
};

/// `mapping` retrieves the decomposition mapping for a code point as per the UCD.
pub fn mapping(self: Self, cp: u21, form: Form) Decomp {
    var dc = Decomp{};

    switch (form) {
        .nfd => {
            dc.cps = self.norm_data.canon_data.toNfd(cp);
            if (dc.cps.len != 0) dc.form = .nfd;
        },

        .nfkd => {
            dc.cps = self.norm_data.compat_data.toNfkd(cp);
            if (dc.cps.len != 0) {
                dc.form = .nfkd;
            } else {
                dc.cps = self.norm_data.canon_data.toNfd(cp);
                if (dc.cps.len != 0) dc.form = .nfkd;
            }
        },

        else => @panic("Normalizer.mapping only accepts form .nfd or .nfkd."),
    }

    return dc;
}

/// `decompose` a code point to the specified normalization form, which should be either `.nfd` or `.nfkd`.
pub fn decompose(
    self: Self,
    cp: u21,
    form: Form,
    buf: []u21,
) Decomp {
    // ASCII
    if (cp < 128) return .{};

    // NFD / NFKD quick checks.
    switch (form) {
        .nfd => if (self.norm_data.normp_data.isNfd(cp)) return .{},
        .nfkd => if (self.norm_data.normp_data.isNfkd(cp)) return .{},
        else => @panic("Normalizer.decompose only accepts form .nfd or .nfkd."),
    }

    // Hangul precomposed syllable full decomposition.
    if (self.decomposeHangul(cp, buf)) |dc| return dc;

    // Full decomposition.
    var dc = Decomp{ .form = form };

    var result_index: usize = 0;
    var work_index: usize = 1;

    // Start work with argument code point.
    var work = [_]u21{cp} ++ [_]u21{0} ** 17;

    while (work_index > 0) {
        // Look at previous code point in work queue.
        work_index -= 1;
        const next = work[work_index];
        const m = self.mapping(next, form);

        // No more of decompositions for this code point.
        if (m.form == .same) {
            buf[result_index] = next;
            result_index += 1;
            continue;
        }

        // Work backwards through decomposition.
        // `i` starts at 1 because m_last is 1 past the last code point.
        var i: usize = 1;
        while (i <= m.cps.len) : ({
            i += 1;
            work_index += 1;
        }) {
            work[work_index] = m.cps[m.cps.len - i];
        }
    }

    dc.cps = buf[0..result_index];

    return dc;
}

test "decompose" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    var buf: [18]u21 = undefined;

    var dc = n.decompose('é', .nfd, &buf);
    try std.testing.expect(dc.form == .nfd);
    try std.testing.expectEqualSlices(u21, &[_]u21{ 'e', '\u{301}' }, dc.cps[0..2]);

    dc = n.decompose('\u{1e0a}', .nfd, &buf);
    try std.testing.expect(dc.form == .nfd);
    try std.testing.expectEqualSlices(u21, &[_]u21{ 'D', '\u{307}' }, dc.cps[0..2]);

    dc = n.decompose('\u{1e0a}', .nfkd, &buf);
    try std.testing.expect(dc.form == .nfkd);
    try std.testing.expectEqualSlices(u21, &[_]u21{ 'D', '\u{307}' }, dc.cps[0..2]);

    dc = n.decompose('\u{3189}', .nfd, &buf);
    try std.testing.expect(dc.form == .same);
    try std.testing.expect(dc.cps.len == 0);

    dc = n.decompose('\u{3189}', .nfkd, &buf);
    try std.testing.expect(dc.form == .nfkd);
    try std.testing.expectEqualSlices(u21, &[_]u21{'\u{1188}'}, dc.cps[0..1]);

    dc = n.decompose('\u{ace1}', .nfd, &buf);
    try std.testing.expect(dc.form == .nfd);
    try std.testing.expectEqualSlices(u21, &[_]u21{ '\u{1100}', '\u{1169}', '\u{11a8}' }, dc.cps[0..3]);

    dc = n.decompose('\u{ace1}', .nfkd, &buf);
    try std.testing.expect(dc.form == .nfd);
    try std.testing.expectEqualSlices(u21, &[_]u21{ '\u{1100}', '\u{1169}', '\u{11a8}' }, dc.cps[0..3]);

    dc = n.decompose('\u{3d3}', .nfd, &buf);
    try std.testing.expect(dc.form == .nfd);
    try std.testing.expectEqualSlices(u21, &[_]u21{ '\u{3d2}', '\u{301}' }, dc.cps[0..2]);

    dc = n.decompose('\u{3d3}', .nfkd, &buf);
    try std.testing.expect(dc.form == .nfkd);
    try std.testing.expectEqualSlices(u21, &[_]u21{ '\u{3a5}', '\u{301}' }, dc.cps[0..2]);
}

/// Returned from various functions in this namespace. Remember to call `deinit` to free any allocated memory.
pub const Result = struct {
    allocator: ?std.mem.Allocator = null,
    slice: []const u8,

    pub fn deinit(self: *Result) void {
        if (self.allocator) |allocator| allocator.free(self.slice);
    }
};

// Compares code points by Canonical Combining Class order.
fn cccLess(self: Self, lhs: u21, rhs: u21) bool {
    return self.norm_data.ccc_data.ccc(lhs) < self.norm_data.ccc_data.ccc(rhs);
}

// Applies the Canonical Sorting Algorithm.
fn canonicalSort(self: Self, cps: []u21) void {
    var i: usize = 0;
    while (i < cps.len) : (i += 1) {
        const start: usize = i;
        while (i < cps.len and self.norm_data.ccc_data.ccc(cps[i]) != 0) : (i += 1) {}
        std.mem.sort(u21, cps[start..i], self, cccLess);
    }
}

/// Normalize `str` to NFD.
pub fn nfd(self: Self, allocator: std.mem.Allocator, str: []const u8) !Result {
    return self.nfxd(allocator, str, .nfd);
}

/// Normalize `str` to NFKD.
pub fn nfkd(self: Self, allocator: std.mem.Allocator, str: []const u8) !Result {
    return self.nfxd(allocator, str, .nfkd);
}

fn nfxd(self: Self, allocator: std.mem.Allocator, str: []const u8, form: Form) !Result {
    // Quick checks.
    if (ascii.isAsciiOnly(str)) return Result{ .slice = str };

    var dcp_list = try std.ArrayList(u21).initCapacity(allocator, str.len * 3);
    defer dcp_list.deinit();

    var cp_iter = CodePointIterator{ .bytes = str };
    var dc_buf: [18]u21 = undefined;

    while (cp_iter.next()) |cp| {
        const dc = self.decompose(cp.code, form, &dc_buf);
        if (dc.form == .same) {
            try dcp_list.append(cp.code);
        } else {
            try dcp_list.appendSlice(dc.cps);
        }
    }

    self.canonicalSort(dcp_list.items);

    var dstr_list = try std.ArrayList(u8).initCapacity(allocator, dcp_list.items.len * 4);
    defer dstr_list.deinit();

    var buf: [4]u8 = undefined;
    for (dcp_list.items) |dcp| {
        const len = try std.unicode.utf8Encode(dcp, &buf);
        dstr_list.appendSliceAssumeCapacity(buf[0..len]);
    }

    return Result{ .allocator = allocator, .slice = try dstr_list.toOwnedSlice() };
}

test "nfd ASCII / no-alloc" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    var result = try n.nfd(allocator, "Hello World!");
    defer result.deinit();

    try std.testing.expectEqualStrings("Hello World!", result.slice);
}

test "nfd !ASCII / alloc" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    var result = try n.nfd(allocator, "Héllo World! \u{3d3}");
    defer result.deinit();

    try std.testing.expectEqualStrings("He\u{301}llo World! \u{3d2}\u{301}", result.slice);
}

test "nfkd ASCII / no-alloc" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    var result = try n.nfkd(allocator, "Hello World!");
    defer result.deinit();

    try std.testing.expectEqualStrings("Hello World!", result.slice);
}

test "nfkd !ASCII / alloc" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    var result = try n.nfkd(allocator, "Héllo World! \u{3d3}");
    defer result.deinit();

    try std.testing.expectEqualStrings("He\u{301}llo World! \u{3a5}\u{301}", result.slice);
}

// Composition utilities.

fn isHangul(self: Self, cp: u21) bool {
    return cp >= 0x1100 and self.norm_data.hangul_data.syllable(cp) != .none;
}

fn isNonHangulStarter(self: Self, cp: u21) bool {
    return !self.isHangul(cp) and self.norm_data.ccc_data.isStarter(cp);
}

/// Normalizes `str` to NFC.
pub fn nfc(self: Self, allocator: std.mem.Allocator, str: []const u8) !Result {
    return self.nfxc(allocator, str, .nfc);
}

/// Normalizes `str` to NFKC.
pub fn nfkc(self: Self, allocator: std.mem.Allocator, str: []const u8) !Result {
    return self.nfxc(allocator, str, .nfkc);
}

fn nfxc(self: Self, allocator: std.mem.Allocator, str: []const u8, form: Form) !Result {
    // Quick checks.
    if (ascii.isAsciiOnly(str)) return Result{ .slice = str };

    // Decompose first.
    var d_result = if (form == .nfc)
        try self.nfd(allocator, str)
    else
        try self.nfkd(allocator, str);
    defer d_result.deinit();

    // Get code points.
    var cp_iter = CodePointIterator{ .bytes = d_result.slice };

    var d_list = try std.ArrayList(u21).initCapacity(allocator, d_result.slice.len);
    defer d_list.deinit();

    while (cp_iter.next()) |cp| d_list.appendAssumeCapacity(cp.code);

    // Compose
    const tombstone = 0xe000; // Start of BMP Private Use Area

    while (true) {
        var i: usize = 1; // start at second code point.
        var deleted: usize = 0;

        block_check: while (i < d_list.items.len) : (i += 1) {
            const C = d_list.items[i];
            const cc_C = self.norm_data.ccc_data.ccc(C);
            var starter_index: ?usize = null;
            var j: usize = i;

            while (true) {
                j -= 1;

                // Check for starter.
                if (self.norm_data.ccc_data.isStarter(d_list.items[j])) {
                    if (i - j > 1) { // If there's distance between the starting point and the current position.
                        for (d_list.items[(j + 1)..i]) |B| {
                            const cc_B = self.norm_data.ccc_data.ccc(B);
                            // Check for blocking conditions.
                            if (self.isHangul(C)) {
                                if (cc_B != 0 or self.isNonHangulStarter(B)) continue :block_check;
                            }
                            if (cc_B >= cc_C) continue :block_check;
                        }
                    }

                    // Found starter at j.
                    starter_index = j;
                    break;
                }

                if (j == 0) break;
            }

            if (starter_index) |sidx| {
                const L = d_list.items[sidx];
                var processed_hangul = false;

                if (self.isHangul(L) and self.isHangul(C)) {
                    const l_stype = self.norm_data.hangul_data.syllable(L);
                    const c_stype = self.norm_data.hangul_data.syllable(C);

                    if (l_stype == .LV and c_stype == .T) {
                        // LV, T
                        d_list.items[sidx] = composeHangulCanon(L, C);
                        d_list.items[i] = tombstone; // Mark for deletion.
                        processed_hangul = true;
                    }

                    if (l_stype == .L and c_stype == .V) {
                        // Handle L, V. L, V, T is handled via main loop.
                        d_list.items[sidx] = composeHangulFull(L, C, 0);
                        d_list.items[i] = tombstone; // Mark for deletion.
                        processed_hangul = true;
                    }

                    if (processed_hangul) deleted += 1;
                }

                if (!processed_hangul) {
                    // L -> C not Hangul.
                    if (self.norm_data.canon_data.toNfc(.{ L, C })) |P| {
                        if (!self.norm_data.normp_data.isFcx(P)) {
                            d_list.items[sidx] = P;
                            d_list.items[i] = tombstone; // Mark for deletion.
                            deleted += 1;
                        }
                    }
                }
            }
        }

        // Check if finished.
        if (deleted == 0) {
            var cstr_list = try std.ArrayList(u8).initCapacity(allocator, d_list.items.len * 4);
            defer cstr_list.deinit();
            var buf: [4]u8 = undefined;

            for (d_list.items) |cp| {
                if (cp == tombstone) continue; // "Delete"
                const len = try std.unicode.utf8Encode(cp, &buf);
                cstr_list.appendSliceAssumeCapacity(buf[0..len]);
            }

            return Result{ .allocator = allocator, .slice = try cstr_list.toOwnedSlice() };
        }

        // Otherwise update code points list.
        var tmp_d_list = try std.ArrayList(u21).initCapacity(allocator, d_list.items.len - deleted);
        defer tmp_d_list.deinit();

        for (d_list.items) |cp| {
            if (cp != tombstone) tmp_d_list.appendAssumeCapacity(cp);
        }

        d_list.clearRetainingCapacity();
        d_list.appendSliceAssumeCapacity(tmp_d_list.items);
    }
}

test "nfc" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    var result = try n.nfc(allocator, "Complex char: \u{3D2}\u{301}");
    defer result.deinit();

    try std.testing.expectEqualStrings("Complex char: \u{3D3}", result.slice);
}

test "nfkc" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    var result = try n.nfkc(allocator, "Complex char: \u{03A5}\u{0301}");
    defer result.deinit();

    try std.testing.expectEqualStrings("Complex char: \u{038E}", result.slice);
}

/// Tests for equality of `a` and `b` after normalizing to NFD.
pub fn eql(self: Self, allocator: std.mem.Allocator, a: []const u8, b: []const u8) !bool {
    var norm_result_a = try self.nfd(allocator, a);
    defer norm_result_a.deinit();
    var norm_result_b = try self.nfd(allocator, b);
    defer norm_result_b.deinit();

    return std.mem.eql(u8, norm_result_a.slice, norm_result_b.slice);
}

test "eql" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    try std.testing.expect(try n.eql(allocator, "foé", "foe\u{0301}"));
    try std.testing.expect(try n.eql(allocator, "foϓ", "fo\u{03D2}\u{0301}"));
}

// FCD
fn getLeadCcc(self: Self, cp: u21) u8 {
    const dc = self.mapping(cp, .nfd);
    const dcp = if (dc.form == .same) cp else dc.cps[0];
    return self.norm_data.ccc_data.ccc(dcp);
}

fn getTrailCcc(self: Self, cp: u21) u8 {
    const dc = self.mapping(cp, .nfd);
    const dcp = if (dc.form == .same) cp else dc.cps[dc.cps.len - 1];
    return self.norm_data.ccc_data.ccc(dcp);
}

/// Fast check to detect if a string is already in NFC or NFD form.
pub fn isFcd(self: Self, str: []const u8) bool {
    var prev_ccc: u8 = 0;
    var cp_iter = CodePointIterator{ .bytes = str };

    return while (cp_iter.next()) |cp| {
        const ccc = self.getLeadCcc(cp.code);
        if (ccc != 0 and ccc < prev_ccc) break false;
        prev_ccc = self.getTrailCcc(cp.code);
    } else true;
}

test "isFcd" {
    const allocator = testing.allocator;
    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    const is_nfc = "José \u{3D3}";
    try std.testing.expect(n.isFcd(is_nfc));

    const is_nfd = "Jose\u{301} \u{3d2}\u{301}";
    try std.testing.expect(n.isFcd(is_nfd));

    const not_fcd = "Jose\u{301} \u{3d2}\u{315}\u{301}";
    try std.testing.expect(!n.isFcd(not_fcd));
}

test "Unicode normalization tests" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var data = try NormData.init(allocator);
    defer data.deinit();
    var n = Self{ .norm_data = &data };

    var file = try std.fs.cwd().openFile("data/unicode/NormalizationTest.txt", .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    const input_stream = buf_reader.reader();

    var line_no: usize = 0;
    var buf: [4096]u8 = undefined;
    var cp_buf: [4]u8 = undefined;

    while (try input_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        line_no += 1;
        // Skip comments or empty lines.
        if (line.len == 0 or line[0] == '#' or line[0] == '@') continue;
        // Iterate over fields.
        var fields = std.mem.split(u8, line, ";");
        var field_index: usize = 0;
        var input: []u8 = undefined;
        defer allocator.free(input);

        while (fields.next()) |field| : (field_index += 1) {
            if (field_index == 0) {
                var i_buf = std.ArrayList(u8).init(allocator);
                defer i_buf.deinit();

                var i_fields = std.mem.split(u8, field, " ");
                while (i_fields.next()) |s| {
                    const icp = try std.fmt.parseInt(u21, s, 16);
                    const len = try std.unicode.utf8Encode(icp, &cp_buf);
                    try i_buf.appendSlice(cp_buf[0..len]);
                }

                input = try i_buf.toOwnedSlice();
            } else if (field_index == 1) {
                //std.debug.print("\n*** {s} ***\n", .{line});
                // NFC, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = std.mem.split(u8, field, " ");
                while (w_fields.next()) |s| {
                    const wcp = try std.fmt.parseInt(u21, s, 16);
                    const len = try std.unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfc(allocator, input);
                defer got.deinit();

                try std.testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 2) {
                // NFD, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = std.mem.split(u8, field, " ");
                while (w_fields.next()) |s| {
                    const wcp = try std.fmt.parseInt(u21, s, 16);
                    const len = try std.unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfd(allocator, input);
                defer got.deinit();

                try std.testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 3) {
                // NFKC, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = std.mem.split(u8, field, " ");
                while (w_fields.next()) |s| {
                    const wcp = try std.fmt.parseInt(u21, s, 16);
                    const len = try std.unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfkc(allocator, input);
                defer got.deinit();

                try std.testing.expectEqualStrings(want, got.slice);
            } else if (field_index == 4) {
                // NFKD, time to test.
                var w_buf = std.ArrayList(u8).init(allocator);
                defer w_buf.deinit();

                var w_fields = std.mem.split(u8, field, " ");
                while (w_fields.next()) |s| {
                    const wcp = try std.fmt.parseInt(u21, s, 16);
                    const len = try std.unicode.utf8Encode(wcp, &cp_buf);
                    try w_buf.appendSlice(cp_buf[0..len]);
                }

                const want = w_buf.items;
                var got = try n.nfkd(allocator, input);
                defer got.deinit();

                try std.testing.expectEqualStrings(want, got.slice);
            } else {
                continue;
            }
        }
    }
}
