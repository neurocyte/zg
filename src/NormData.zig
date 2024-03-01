const std = @import("std");
const mem = std.mem;

const CanonData = @import("CanonData");
const CccData = @import("CombiningData");
const CompatData = @import("CompatData");
const FoldData = @import("FoldData");
const HangulData = @import("HangulData");
const NormPropsData = @import("NormPropsData");

canon_data: CanonData,
ccc_data: CccData,
compat_data: CompatData,
hangul_data: HangulData,
normp_data: NormPropsData,
fold_data: FoldData,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .canon_data = try CanonData.init(allocator),
        .ccc_data = try CccData.init(allocator),
        .compat_data = try CompatData.init(allocator),
        .fold_data = try FoldData.init(allocator),
        .hangul_data = try HangulData.init(allocator),
        .normp_data = try NormPropsData.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.canon_data.deinit();
    self.ccc_data.deinit();
    self.compat_data.deinit();
    self.hangul_data.deinit();
    self.fold_data.deinit();
    self.normp_data.deinit();
}
