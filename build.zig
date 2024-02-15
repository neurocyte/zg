const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const ziglyph = b.dependency("ziglyph", .{});

    // Code generation
    const gbp_gen_exe = b.addExecutable(.{
        .name = "gbp",
        .root_source_file = .{ .path = "codegen/gbp.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_gbp_gen_exe = b.addRunArtifact(gbp_gen_exe);
    const gbp_gen_out = run_gbp_gen_exe.addOutputFileArg("gbp.zig");

    // Modules we provide
    const code_point = b.addModule("CodePoint", .{
        .root_source_file = .{ .path = "src/CodePoint.zig" },
        .target = target,
        .optimize = optimize,
    });

    const grapheme = b.addModule("Grapheme", .{
        .root_source_file = .{ .path = "src/Grapheme.zig" },
        .target = target,
        .optimize = optimize,
    });
    grapheme.addImport("CodePoint", code_point);
    grapheme.addAnonymousImport("gbp", .{ .root_source_file = gbp_gen_out });

    // Benchmark rig
    const exe = b.addExecutable(.{
        .name = "zgbench",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    exe.root_module.addImport("Grapheme", grapheme);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    exe_unit_tests.root_module.addImport("Grapheme", grapheme);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
