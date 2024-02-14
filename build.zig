const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziglyph = b.dependency("ziglyph", .{});

    const gbp_gen_exe = b.addExecutable(.{
        .name = "grapheme_break",
        .root_source_file = .{ .path = "codegen/grapheme_break.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    gbp_gen_exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    const run_gbp_gen_exe = b.addRunArtifact(gbp_gen_exe);
    const gbp_gen_out = run_gbp_gen_exe.addOutputFileArg("gbp.zig");

    const emoji_gen_exe = b.addExecutable(.{
        .name = "emoji",
        .root_source_file = .{ .path = "codegen/emoji.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    emoji_gen_exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    const run_emoji_gen_exe = b.addRunArtifact(emoji_gen_exe);
    const emoji_gen_out = run_emoji_gen_exe.addOutputFileArg("emoji.zig");

    const indic_gen_exe = b.addExecutable(.{
        .name = "indic",
        .root_source_file = .{ .path = "codegen/indic.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    indic_gen_exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    const run_indic_gen_exe = b.addRunArtifact(indic_gen_exe);
    const indic_gen_out = run_indic_gen_exe.addOutputFileArg("indic.zig");

    const exe = b.addExecutable(.{
        .name = "zgbench",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    exe.root_module.addAnonymousImport("gbp", .{ .root_source_file = gbp_gen_out });
    exe.root_module.addAnonymousImport("emoji", .{ .root_source_file = emoji_gen_out });
    exe.root_module.addAnonymousImport("indic", .{ .root_source_file = indic_gen_out });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    exe_unit_tests.root_module.addAnonymousImport("gbp", .{ .root_source_file = gbp_gen_out });
    exe_unit_tests.root_module.addAnonymousImport("emoji", .{ .root_source_file = emoji_gen_out });
    exe_unit_tests.root_module.addAnonymousImport("indic", .{ .root_source_file = indic_gen_out });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
