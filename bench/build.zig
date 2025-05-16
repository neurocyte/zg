const std = @import("std");

const Import = struct {
    name: []const u8,
    module: *std.Build.Module,
};

const Bench = struct {
    name: []const u8,
    src: []const u8,
    imports: []const Import,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziglyph = b.dependency("ziglyph", .{});
    const zg = b.dependency("zg", .{});

    const benches = [_]Bench{
        .{
            .name = "ziglyph_normalizer",
            .src = "src/ziglyph_normalizer.zig",
            .imports = &.{
                .{ .name = "ziglyph", .module = ziglyph.module("ziglyph") },
            },
        },
        .{
            .name = "ziglyph_caseless",
            .src = "src/ziglyph_caseless.zig",
            .imports = &.{
                .{ .name = "ziglyph", .module = ziglyph.module("ziglyph") },
            },
        },
        .{
            .name = "ziglyph_codepoint",
            .src = "src/ziglyph_codepoint.zig",
            .imports = &.{
                .{ .name = "ziglyph", .module = ziglyph.module("ziglyph") },
            },
        },
        .{
            .name = "ziglyph_grapheme",
            .src = "src/ziglyph_grapheme.zig",
            .imports = &.{
                .{ .name = "ziglyph", .module = ziglyph.module("ziglyph") },
            },
        },
        .{
            .name = "ziglyph_width",
            .src = "src/ziglyph_width.zig",
            .imports = &.{
                .{ .name = "ziglyph", .module = ziglyph.module("ziglyph") },
            },
        },
        .{
            .name = "ziglyph_case",
            .src = "src/ziglyph_case.zig",
            .imports = &.{
                .{ .name = "ziglyph", .module = ziglyph.module("ziglyph") },
            },
        },

        .{
            .name = "zg_normalize",
            .src = "src/zg_normalize.zig",
            .imports = &.{
                .{ .name = "Normalize", .module = zg.module("Normalize") },
            },
        },
        .{
            .name = "zg_caseless",
            .src = "src/zg_caseless.zig",
            .imports = &.{
                .{ .name = "CaseFolding", .module = zg.module("CaseFolding") },
                .{ .name = "Normalize", .module = zg.module("Normalize") },
            },
        },
        .{
            .name = "zg_codepoint",
            .src = "src/zg_codepoint.zig",
            .imports = &.{
                .{ .name = "code_point", .module = zg.module("code_point") },
            },
        },
        .{
            .name = "zg_grapheme",
            .src = "src/zg_grapheme.zig",
            .imports = &.{
                .{ .name = "Graphemes", .module = zg.module("Graphemes") },
            },
        },
        .{
            .name = "zg_width",
            .src = "src/zg_width.zig",
            .imports = &.{
                .{ .name = "DisplayWidth", .module = zg.module("DisplayWidth") },
            },
        },
        .{
            .name = "zg_case",
            .src = "src/zg_case.zig",
            .imports = &.{
                .{ .name = "LetterCasing", .module = zg.module("LetterCasing") },
            },
        },
    };

    for (&benches) |bench| {
        const exe = b.addExecutable(.{
            .name = bench.name,
            .root_source_file = b.path(bench.src),
            .target = target,
            .optimize = optimize,
            .strip = true,
        });

        for (bench.imports) |import| {
            exe.root_module.addImport(import.name, import.module);
        }

        b.installArtifact(exe);
    }

    // Tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("GeneralCategories", zg.module("GeneralCategories"));
    unit_tests.root_module.addImport("Properties", zg.module("Properties"));
    unit_tests.root_module.addImport("LetterCasing", zg.module("LetterCasing"));
    unit_tests.root_module.addImport("Normalize", zg.module("Normalize"));
    unit_tests.root_module.addImport("CaseFolding", zg.module("CaseFolding"));
    unit_tests.root_module.addImport("DisplayWidth", zg.module("DisplayWidth"));
    unit_tests.root_module.addImport("code_point", zg.module("code_point"));
    unit_tests.root_module.addImport("Graphemes", zg.module("Graphemes"));
    unit_tests.root_module.addImport("Scripts", zg.module("Scripts"));

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const unit_test_step = b.step("test", "Run tests");
    unit_test_step.dependOn(&run_unit_tests.step);
}
