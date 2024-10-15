const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;
const testing = std.testing;

const GraphemeData = @import("GraphemeData");

allocator: mem.Allocator,
g_data: GraphemeData,
s1: []u16 = undefined,
s2: []i3 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) mem.Allocator.Error!Self {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("dwp");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();

    var self = Self{
        .allocator = allocator,
        .g_data = try GraphemeData.init(allocator),
    };
    errdefer self.g_data.deinit();

    const stage_1_len: u16 = reader.readInt(u16, endian) catch unreachable;
    self.s1 = try allocator.alloc(u16, stage_1_len);
    errdefer allocator.free(self.s1);
    for (0..stage_1_len) |i| self.s1[i] = reader.readInt(u16, endian) catch unreachable;

    const stage_2_len: u16 = reader.readInt(u16, endian) catch unreachable;
    self.s2 = try allocator.alloc(i3, stage_2_len);
    errdefer allocator.free(self.s2);
    for (0..stage_2_len) |i| self.s2[i] = @intCast(reader.readInt(i8, endian) catch unreachable);

    return self;
}

pub fn deinit(self: *const Self) void {
    self.allocator.free(self.s1);
    self.allocator.free(self.s2);
    self.g_data.deinit();
}

/// codePointWidth returns the number of cells `cp` requires when rendered
/// in a fixed-pitch font (i.e. a terminal screen). This can range from -1 to
/// 3, where BACKSPACE and DELETE return -1 and 3-em-dash returns 3. C0/C1
/// control codes return 0. If `cjk` is true, ambiguous code points return 2,
/// otherwise they return 1.
pub fn codePointWidth(self: Self, cp: u21) i3 {
    return self.s2[self.s1[cp >> 8] + (cp & 0xff)];
}

test "codePointWidth" {
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x0000)); // null
    try testing.expectEqual(@as(i3, -1), codePointWidth(0x8)); // \b
    try testing.expectEqual(@as(i3, -1), codePointWidth(0x7f)); // DEL
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x0005)); // Cf
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x0007)); // \a BEL
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000A)); // \n LF
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000B)); // \v VT
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000C)); // \f FF
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000D)); // \r CR
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000E)); // SQ
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000F)); // SI

    try testing.expectEqual(@as(i3, 0), codePointWidth(0x070F)); // Cf
    try testing.expectEqual(@as(i3, 1), codePointWidth(0x0603)); // Cf Arabic

    try testing.expectEqual(@as(i3, 1), codePointWidth(0x00AD)); // soft-hyphen
    try testing.expectEqual(@as(i3, 2), codePointWidth(0x2E3A)); // two-em dash
    try testing.expectEqual(@as(i3, 3), codePointWidth(0x2E3B)); // three-em dash

    try testing.expectEqual(@as(i3, 1), codePointWidth(0x00BD)); // ambiguous halfwidth

    try testing.expectEqual(@as(i3, 1), codePointWidth('é'));
    try testing.expectEqual(@as(i3, 2), codePointWidth('😊'));
    try testing.expectEqual(@as(i3, 2), codePointWidth('统'));
}
