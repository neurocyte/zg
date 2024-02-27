const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;
const testing = std.testing;

allocator: mem.Allocator,
s1: []u16 = undefined,
s2: []u4 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.deflate.decompressor;
    const in_bytes = @embedFile("normp");
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
    self.s2 = try allocator.alloc(u4, stage_2_len);
    for (0..stage_2_len) |i| self.s2[i] = @intCast(try reader.readInt(u8, endian));

    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.s1);
    self.allocator.free(self.s2);
}

/// Returns true if `cp` is already in NFD form.
pub inline fn isNfd(self: Self, cp: u21) bool {
    return self.s2[self.s1[cp >> 8] + (cp & 0xff)] & 1 == 0;
}

/// Returns true if `cp` is already in NFKD form.
pub inline fn isNfkd(self: Self, cp: u21) bool {
    return self.s2[self.s1[cp >> 8] + (cp & 0xff)] & 2 == 0;
}

/// Returns true if `cp` is not allowed in any normalized form.
pub inline fn isFcx(self: Self, cp: u21) bool {
    return self.s2[self.s1[cp >> 8] + (cp & 0xff)] & 4 == 4;
}
