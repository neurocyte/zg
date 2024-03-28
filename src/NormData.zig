const std = @import("std");
const mem = std.mem;

const CanonData = @import("CanonData");
const CccData = @import("CombiningData");
const CompatData = @import("CompatData");
const FoldData = @import("FoldData");
const HangulData = @import("HangulData");
const NormPropsData = @import("NormPropsData");

canon_data: CanonData = undefined,
ccc_data: CccData = undefined,
compat_data: CompatData = undefined,
hangul_data: HangulData = undefined,
normp_data: NormPropsData = undefined,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !Self {
    var self = Self{};
    self.canon_data = try CanonData.init(allocator);
    errdefer self.canon_data.deinit();
    self.ccc_data = try CccData.init(allocator);
    errdefer self.ccc_data.deinit();
    self.compat_data = try CompatData.init(allocator);
    errdefer self.compat_data.deinit();
    self.hangul_data = try HangulData.init(allocator);
    errdefer self.hangul_data.deinit();
    self.normp_data = try NormPropsData.init(allocator);

    return self;
}

pub fn deinit(self: *Self) void {
    self.canon_data.deinit();
    self.ccc_data.deinit();
    self.compat_data.deinit();
    self.hangul_data.deinit();
    self.normp_data.deinit();
}
