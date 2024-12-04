const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

allocator: mem.Allocator,
cutoff: u21 = undefined,
cwcf_exceptions_min: u21 = undefined,
cwcf_exceptions_max: u21 = undefined,
cwcf_exceptions: []u21 = undefined,
multiple_start: u21 = undefined,
stage1: []u8 = undefined,
stage2: []u8 = undefined,
stage3: []i24 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("fold");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();

    var self = Self{ .allocator = allocator };
    self.cutoff = @intCast(try reader.readInt(u24, endian));
    self.multiple_start = @intCast(try reader.readInt(u24, endian));

    var len = try reader.readInt(u16, endian);
    self.stage1 = try allocator.alloc(u8, len);
    errdefer allocator.free(self.stage1);
    for (0..len) |i| self.stage1[i] = try reader.readInt(u8, endian);

    len = try reader.readInt(u16, endian);
    self.stage2 = try allocator.alloc(u8, len);
    errdefer allocator.free(self.stage2);
    for (0..len) |i| self.stage2[i] = try reader.readInt(u8, endian);

    len = try reader.readInt(u16, endian);
    self.stage3 = try allocator.alloc(i24, len);
    errdefer allocator.free(self.stage3);
    for (0..len) |i| self.stage3[i] = try reader.readInt(i24, endian);

    self.cwcf_exceptions_min = @intCast(try reader.readInt(u24, endian));
    self.cwcf_exceptions_max = @intCast(try reader.readInt(u24, endian));
    len = try reader.readInt(u16, endian);
    self.cwcf_exceptions = try allocator.alloc(u21, len);
    errdefer allocator.free(self.cwcf_exceptions);
    for (0..len) |i| self.cwcf_exceptions[i] = @intCast(try reader.readInt(u24, endian));

    return self;
}

pub fn deinit(self: *const Self) void {
    self.allocator.free(self.stage1);
    self.allocator.free(self.stage2);
    self.allocator.free(self.stage3);
    self.allocator.free(self.cwcf_exceptions);
}

/// Returns the case fold for `cp`.
pub fn caseFold(self: Self, cp: u21, buf: []u21) []const u21 {
    if (cp >= self.cutoff) return &.{};

    const stage1_val = self.stage1[cp >> 8];
    if (stage1_val == 0) return &.{};

    const stage2_index = @as(usize, stage1_val) * 256 + (cp & 0xFF);
    const stage3_index = self.stage2[stage2_index];

    if (stage3_index & 0x80 != 0) {
        const real_index = @as(usize, self.multiple_start) + (stage3_index ^ 0x80) * 3;
        const mapping = mem.sliceTo(self.stage3[real_index..][0..3], 0);
        for (mapping, 0..) |c, i| buf[i] = @intCast(c);

        return buf[0..mapping.len];
    }

    const offset = self.stage3[stage3_index];
    if (offset == 0) return &.{};

    buf[0] = @intCast(@as(i32, cp) + offset);

    return buf[0..1];
}

/// Returns true when caseFold(NFD(`cp`)) != NFD(`cp`).
pub fn changesWhenCaseFolded(self: Self, cp: u21) bool {
    var buf: [3]u21 = undefined;
    const has_mapping = self.caseFold(cp, &buf).len != 0;
    return has_mapping and !self.isCwcfException(cp);
}

fn isCwcfException(self: Self, cp: u21) bool {
    return cp >= self.cwcf_exceptions_min and
        cp <= self.cwcf_exceptions_max and
        std.mem.indexOfScalar(u21, self.cwcf_exceptions, cp) != null;
}
