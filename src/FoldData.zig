const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

allocator: mem.Allocator,
fold: [][]u21 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.deflate.decompressor;
    const in_bytes = @embedFile("fold");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = try decompressor(allocator, in_fbs.reader(), null);
    defer in_decomp.deinit();
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();
    var self = Self{
        .allocator = allocator,
        .fold = try allocator.alloc([]u21, 0x110000),
    };

    @memset(self.fold, &.{});

    while (true) {
        const len: u8 = try reader.readInt(u8, endian);
        if (len == 0) break;
        const cp = try reader.readInt(u24, endian);
        self.fold[cp] = try allocator.alloc(u21, len - 1);
        for (0..len - 1) |i| {
            self.fold[cp][i] = @intCast(try reader.readInt(u24, endian));
        }
    }

    return self;
}

pub fn deinit(self: *Self) void {
    for (self.fold) |slice| self.allocator.free(slice);
    self.allocator.free(self.fold);
}

/// Returns the case fold for `cp`.
pub inline fn caseFold(self: Self, cp: u21) []const u21 {
    return self.fold[cp];
}
