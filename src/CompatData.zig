//! Compatibility Data

nfkd: [][]u21 = undefined,

const CompatData = @This();

pub fn init(allocator: mem.Allocator) !CompatData {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("compat");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();
    var cpdata = CompatData{
        .nfkd = try allocator.alloc([]u21, 0x110000),
    };
    errdefer cpdata.deinit(allocator);

    @memset(cpdata.nfkd, &.{});

    while (true) {
        const len: u8 = try reader.readInt(u8, endian);
        if (len == 0) break;
        const cp = try reader.readInt(u24, endian);
        cpdata.nfkd[cp] = try allocator.alloc(u21, len - 1);
        for (0..len - 1) |i| {
            cpdata.nfkd[cp][i] = @intCast(try reader.readInt(u24, endian));
        }
    }

    return cpdata;
}

pub fn deinit(cpdata: *const CompatData, allocator: mem.Allocator) void {
    for (cpdata.nfkd) |slice| {
        if (slice.len != 0) allocator.free(slice);
    }
    allocator.free(cpdata.nfkd);
}

/// Returns compatibility decomposition for `cp`.
pub fn toNfkd(cpdata: *const CompatData, cp: u21) []u21 {
    return cpdata.nfkd[cp];
}

const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;
