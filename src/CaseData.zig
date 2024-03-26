const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;
const testing = std.testing;
const unicode = std.unicode;

const CodePointIterator = @import("code_point").Iterator;

allocator: mem.Allocator,
case_map: [][3]u21,
prop_s1: []u16 = undefined,
prop_s2: []u8 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.deflate.decompressor;
    const endian = builtin.cpu.arch.endian();

    var self = Self{
        .allocator = allocator,
        .case_map = try allocator.alloc([3]u21, 0x110000),
    };
    errdefer allocator.free(self.case_map);

    for (0..0x110000) |i| {
        const cp: u21 = @intCast(i);
        self.case_map[cp] = .{ cp, cp, cp };
    }

    // Uppercase
    const upper_bytes = @embedFile("upper");
    var upper_fbs = std.io.fixedBufferStream(upper_bytes);
    var upper_decomp = try decompressor(allocator, upper_fbs.reader(), null);
    defer upper_decomp.deinit();
    var upper_reader = upper_decomp.reader();

    while (true) {
        const cp = try upper_reader.readInt(u24, endian);
        if (cp == 0) break;
        self.case_map[cp][0] = @intCast(try upper_reader.readInt(u24, endian));
    }

    // Lowercase
    const lower_bytes = @embedFile("lower");
    var lower_fbs = std.io.fixedBufferStream(lower_bytes);
    var lower_decomp = try decompressor(allocator, lower_fbs.reader(), null);
    defer lower_decomp.deinit();
    var lower_reader = lower_decomp.reader();

    while (true) {
        const cp = try lower_reader.readInt(u24, endian);
        if (cp == 0) break;
        self.case_map[cp][1] = @intCast(try lower_reader.readInt(u24, endian));
    }

    // Titlercase
    const title_bytes = @embedFile("title");
    var title_fbs = std.io.fixedBufferStream(title_bytes);
    var title_decomp = try decompressor(allocator, title_fbs.reader(), null);
    defer title_decomp.deinit();
    var title_reader = title_decomp.reader();

    while (true) {
        const cp = try title_reader.readInt(u24, endian);
        if (cp == 0) break;
        self.case_map[cp][2] = @intCast(try title_reader.readInt(u24, endian));
    }

    // Case properties
    const cp_bytes = @embedFile("case_prop");
    var cp_fbs = std.io.fixedBufferStream(cp_bytes);
    var cp_decomp = try decompressor(allocator, cp_fbs.reader(), null);
    defer cp_decomp.deinit();
    var cp_reader = cp_decomp.reader();

    const stage_1_len: u16 = try cp_reader.readInt(u16, endian);
    self.prop_s1 = try allocator.alloc(u16, stage_1_len);
    errdefer allocator.free(self.prop_s1);
    for (0..stage_1_len) |i| self.prop_s1[i] = try cp_reader.readInt(u16, endian);

    const stage_2_len: u16 = try cp_reader.readInt(u16, endian);
    self.prop_s2 = try allocator.alloc(u8, stage_2_len);
    errdefer allocator.free(self.prop_s2);
    _ = try cp_reader.readAll(self.prop_s2);

    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.case_map);
    self.allocator.free(self.prop_s1);
    self.allocator.free(self.prop_s2);
}

// Returns true if `cp` is either upper, lower, or title case.
pub inline fn isCased(self: Self, cp: u21) bool {
    return self.prop_s2[self.prop_s1[cp >> 8] + (cp & 0xff)] & 4 == 4;
}

// Returns true if `cp` is uppercase.
pub fn isUpper(self: Self, cp: u21) bool {
    if (!self.isCased(cp)) return true;
    return self.prop_s2[self.prop_s1[cp >> 8] + (cp & 0xff)] & 2 == 2;
}

/// Returns true if `str` is all uppercase.
pub fn isUpperStr(self: Self, str: []const u8) bool {
    var iter = CodePointIterator{ .bytes = str };

    return while (iter.next()) |cp| {
        if (!self.isUpper(cp.code)) break false;
    } else true;
}

test "isUpperStr" {
    var cd = try init(testing.allocator);
    defer cd.deinit();

    try testing.expect(cd.isUpperStr("HELLO, WORLD 2112!"));
    try testing.expect(!cd.isUpperStr("hello, world 2112!"));
    try testing.expect(!cd.isUpperStr("Hello, World 2112!"));
}

/// Returns a new string with all letters in uppercase.
/// Caller must free returned bytes with `allocator`.
pub fn toUpperStr(
    self: Self,
    allocator: mem.Allocator,
    str: []const u8,
) ![]u8 {
    var bytes = std.ArrayList(u8).init(allocator);
    defer bytes.deinit();

    var iter = CodePointIterator{ .bytes = str };
    var buf: [4]u8 = undefined;

    while (iter.next()) |cp| {
        const len = try unicode.utf8Encode(self.toUpper(cp.code), &buf);
        try bytes.appendSlice(buf[0..len]);
    }

    return try bytes.toOwnedSlice();
}

test "toUpperStr" {
    var cd = try init(testing.allocator);
    defer cd.deinit();

    const uppered = try cd.toUpperStr(testing.allocator, "Hello, World 2112!");
    defer testing.allocator.free(uppered);
    try testing.expectEqualStrings("HELLO, WORLD 2112!", uppered);
}

/// Returns uppercase mapping for `cp`.
pub inline fn toUpper(self: Self, cp: u21) u21 {
    return self.case_map[cp][0];
}

// Returns true if `cp` is lowercase.
pub fn isLower(self: Self, cp: u21) bool {
    if (!self.isCased(cp)) return true;
    return self.prop_s2[self.prop_s1[cp >> 8] + (cp & 0xff)] & 1 == 1;
}

/// Returns lowercase mapping for `cp`.
pub inline fn toLower(self: Self, cp: u21) u21 {
    return self.case_map[cp][1];
}

/// Returns true if `str` is all lowercase.
pub fn isLowerStr(self: Self, str: []const u8) bool {
    var iter = CodePointIterator{ .bytes = str };

    return while (iter.next()) |cp| {
        if (!self.isLower(cp.code)) break false;
    } else true;
}

test "isLowerStr" {
    var cd = try init(testing.allocator);
    defer cd.deinit();

    try testing.expect(cd.isLowerStr("hello, world 2112!"));
    try testing.expect(!cd.isLowerStr("HELLO, WORLD 2112!"));
    try testing.expect(!cd.isLowerStr("Hello, World 2112!"));
}

/// Returns a new string with all letters in lowercase.
/// Caller must free returned bytes with `allocator`.
pub fn toLowerStr(
    self: Self,
    allocator: mem.Allocator,
    str: []const u8,
) ![]u8 {
    var bytes = std.ArrayList(u8).init(allocator);
    defer bytes.deinit();

    var iter = CodePointIterator{ .bytes = str };
    var buf: [4]u8 = undefined;

    while (iter.next()) |cp| {
        const len = try unicode.utf8Encode(self.toLower(cp.code), &buf);
        try bytes.appendSlice(buf[0..len]);
    }

    return try bytes.toOwnedSlice();
}

test "toLowerStr" {
    var cd = try init(testing.allocator);
    defer cd.deinit();

    const lowered = try cd.toLowerStr(testing.allocator, "Hello, World 2112!");
    defer testing.allocator.free(lowered);
    try testing.expectEqualStrings("hello, world 2112!", lowered);
}

/// Returns titlecase mapping for `cp`.
pub inline fn toTitle(self: Self, cp: u21) u21 {
    return self.case_map[cp][2];
}
