const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const ziglyph = b.dependency("ziglyph", .{});

    // Code generation
    // Grapheme break
    const gbp_gen_exe = b.addExecutable(.{
        .name = "gbp",
        .root_source_file = .{ .path = "codegen/gbp.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_gbp_gen_exe = b.addRunArtifact(gbp_gen_exe);
    const gbp_gen_out = run_gbp_gen_exe.addOutputFileArg("gbp.zig");

    // Display width
    const cjk = b.option(bool, "cjk", "Ambiguouse code points are wide (display width: 2).") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "cjk", cjk);

    const dwp_gen_exe = b.addExecutable(.{
        .name = "dwp",
        .root_source_file = .{ .path = "codegen/dwp.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    dwp_gen_exe.root_module.addOptions("options", options);
    const run_dwp_gen_exe = b.addRunArtifact(dwp_gen_exe);
    const dwp_gen_out = run_dwp_gen_exe.addOutputFileArg("dwp.zig");

    // Normalization properties
    const normp_gen_exe = b.addExecutable(.{
        .name = "normp",
        .root_source_file = .{ .path = "codegen/normp.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_normp_gen_exe = b.addRunArtifact(normp_gen_exe);
    const normp_gen_out = run_normp_gen_exe.addOutputFileArg("normp.zig");

    // Modules we provide
    // Code points
    const code_point = b.addModule("code_point", .{
        .root_source_file = .{ .path = "src/code_point.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Grapheme clusters
    const grapheme = b.addModule("grapheme", .{
        .root_source_file = .{ .path = "src/grapheme.zig" },
        .target = target,
        .optimize = optimize,
    });
    grapheme.addImport("code_point", code_point);
    grapheme.addAnonymousImport("gbp", .{ .root_source_file = gbp_gen_out });

    // ASCII utilities
    const ascii = b.addModule("ascii", .{
        .root_source_file = .{ .path = "src/ascii.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Fixed pitch font display width
    const display_width = b.addModule("display_width", .{
        .root_source_file = .{ .path = "src/display_width.zig" },
        .target = target,
        .optimize = optimize,
    });
    display_width.addImport("ascii", ascii);
    display_width.addImport("code_point", code_point);
    display_width.addImport("grapheme", grapheme);
    display_width.addAnonymousImport("dwp", .{ .root_source_file = dwp_gen_out });

    // Normalization
    const norm = b.addModule("Normalizer", .{
        .root_source_file = .{ .path = "src/Normalizer.zig" },
        .target = target,
        .optimize = optimize,
    });
    norm.addImport("code_point", code_point);
    norm.addImport("ziglyph", ziglyph.module("ziglyph"));
    norm.addAnonymousImport("normp", .{ .root_source_file = normp_gen_out });

    // Benchmark rig
    const exe = b.addExecutable(.{
        .name = "zg",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    exe.root_module.addImport("ascii", ascii);
    exe.root_module.addImport("code_point", code_point);
    exe.root_module.addImport("grapheme", grapheme);
    exe.root_module.addImport("display_width", display_width);
    exe.root_module.addImport("Normalizer", norm);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/Normalizer.zig" },
        .target = target,
        .optimize = optimize,
    });
    // exe_unit_tests.root_module.addImport("ascii", ascii);
    exe_unit_tests.root_module.addImport("code_point", code_point);
    // exe_unit_tests.root_module.addImport("grapheme", grapheme);
    // exe_unit_tests.root_module.addAnonymousImport("gbp", .{ .root_source_file = gbp_gen_out });
    // exe_unit_tests.root_module.addAnonymousImport("dwp", .{ .root_source_file = dwp_gen_out });
    exe_unit_tests.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    exe_unit_tests.root_module.addAnonymousImport("normp", .{ .root_source_file = normp_gen_out });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
