const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

cutoff: u21 = undefined,
cwcf_exceptions_min: u21 = undefined,
cwcf_exceptions_max: u21 = undefined,
cwcf_exceptions: []u21 = undefined,
multiple_start: u21 = undefined,
stage1: []u8 = undefined,
stage2: []u8 = undefined,
stage3: []i24 = undefined,

const FoldData = @This();

pub fn init(allocator: mem.Allocator) !FoldData {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("fold");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();

    var fdata = FoldData{};
    fdata.cutoff = @intCast(try reader.readInt(u24, endian));
    fdata.multiple_start = @intCast(try reader.readInt(u24, endian));

    var len = try reader.readInt(u16, endian);
    fdata.stage1 = try allocator.alloc(u8, len);
    errdefer allocator.free(fdata.stage1);
    for (0..len) |i| fdata.stage1[i] = try reader.readInt(u8, endian);

    len = try reader.readInt(u16, endian);
    fdata.stage2 = try allocator.alloc(u8, len);
    errdefer allocator.free(fdata.stage2);
    for (0..len) |i| fdata.stage2[i] = try reader.readInt(u8, endian);

    len = try reader.readInt(u16, endian);
    fdata.stage3 = try allocator.alloc(i24, len);
    errdefer allocator.free(fdata.stage3);
    for (0..len) |i| fdata.stage3[i] = try reader.readInt(i24, endian);

    fdata.cwcf_exceptions_min = @intCast(try reader.readInt(u24, endian));
    fdata.cwcf_exceptions_max = @intCast(try reader.readInt(u24, endian));
    len = try reader.readInt(u16, endian);
    fdata.cwcf_exceptions = try allocator.alloc(u21, len);
    errdefer allocator.free(fdata.cwcf_exceptions);
    for (0..len) |i| fdata.cwcf_exceptions[i] = @intCast(try reader.readInt(u24, endian));

    return fdata;
}

pub fn deinit(fdata: *const FoldData, allocator: mem.Allocator) void {
    allocator.free(fdata.stage1);
    allocator.free(fdata.stage2);
    allocator.free(fdata.stage3);
    allocator.free(fdata.cwcf_exceptions);
}

/// Returns the case fold for `cp`.
pub fn caseFold(fdata: *const FoldData, cp: u21, buf: []u21) []const u21 {
    if (cp >= fdata.cutoff) return &.{};

    const stage1_val = fdata.stage1[cp >> 8];
    if (stage1_val == 0) return &.{};

    const stage2_index = @as(usize, stage1_val) * 256 + (cp & 0xFF);
    const stage3_index = fdata.stage2[stage2_index];

    if (stage3_index & 0x80 != 0) {
        const real_index = @as(usize, fdata.multiple_start) + (stage3_index ^ 0x80) * 3;
        const mapping = mem.sliceTo(fdata.stage3[real_index..][0..3], 0);
        for (mapping, 0..) |c, i| buf[i] = @intCast(c);

        return buf[0..mapping.len];
    }

    const offset = fdata.stage3[stage3_index];
    if (offset == 0) return &.{};

    buf[0] = @intCast(@as(i32, cp) + offset);

    return buf[0..1];
}

/// Returns true when caseFold(NFD(`cp`)) != NFD(`cp`).
pub fn changesWhenCaseFolded(fdata: *const FoldData, cp: u21) bool {
    var buf: [3]u21 = undefined;
    const has_mapping = fdata.caseFold(cp, &buf).len != 0;
    return has_mapping and !fdata.isCwcfException(cp);
}

fn isCwcfException(fdata: *const FoldData, cp: u21) bool {
    return cp >= fdata.cwcf_exceptions_min and
        cp <= fdata.cwcf_exceptions_max and
        std.mem.indexOfScalar(u21, fdata.cwcf_exceptions, cp) != null;
}
