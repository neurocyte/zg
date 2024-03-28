const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;
const testing = std.testing;

allocator: mem.Allocator,
s1: []u16 = undefined,
s2: []u8 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.deflate.decompressor;
    const in_bytes = @embedFile("numeric");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = try decompressor(allocator, in_fbs.reader(), null);
    defer in_decomp.deinit();
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();

    var self = Self{ .allocator = allocator };

    const stage_1_len: u16 = try reader.readInt(u16, endian);
    self.s1 = try allocator.alloc(u16, stage_1_len);
    for (0..stage_1_len) |i| self.s1[i] = try reader.readInt(u16, endian);

    const stage_2_len: u16 = try reader.readInt(u16, endian);
    self.s2 = try allocator.alloc(u8, stage_2_len);
    _ = try reader.readAll(self.s2);

    return self;
}

pub fn deinit(self: *const Self) void {
    self.allocator.free(self.s1);
    self.allocator.free(self.s2);
}

/// True if `cp` is any numeric type.
pub fn isNumber(self: Self, cp: u21) bool {
    return self.isNumeric(cp) or self.isDigit(cp) or self.isDecimal(cp);
}

/// True if `cp` is numeric.
pub inline fn isNumeric(self: Self, cp: u21) bool {
    return self.s2[self.s1[cp >> 8] + (cp & 0xff)] & 1 == 1;
}

/// True if `cp` is a digit.
pub inline fn isDigit(self: Self, cp: u21) bool {
    return self.s2[self.s1[cp >> 8] + (cp & 0xff)] & 2 == 2;
}

/// True if `cp` is decimal.
pub inline fn isDecimal(self: Self, cp: u21) bool {
    return self.s2[self.s1[cp >> 8] + (cp & 0xff)] & 4 == 4;
}

test "isDecimal" {
    const self = try init(testing.allocator);
    defer self.deinit();

    try testing.expect(self.isNumber('\u{277f}'));
    try testing.expect(self.isNumber('3'));
    try testing.expect(self.isNumeric('\u{277f}'));
    try testing.expect(self.isDigit('\u{2070}'));
    try testing.expect(self.isDecimal('3'));

    try testing.expect(!self.isNumber('z'));
    try testing.expect(!self.isNumeric('1'));
    try testing.expect(!self.isDigit('2'));
    try testing.expect(!self.isDecimal('g'));
}
