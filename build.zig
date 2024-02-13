const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziglyph = b.dependency("ziglyph", .{});

    const gen_exe = b.addExecutable(.{
        .name = "gen",
        .root_source_file = .{ .path = "src/gbp_gen.zig" },
        .target = target,
        .optimize = optimize,
    });
    gen_exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    const run_gen_exe = b.addRunArtifact(gen_exe);
    const gen_out = run_gen_exe.addOutputFileArg("gbp.zig");

    const exe = b.addExecutable(.{
        .name = "zgbench",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    exe.root_module.addAnonymousImport("gbp", .{ .root_source_file = gen_out });
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
    exe_unit_tests.root_module.addAnonymousImport("gbp", .{ .root_source_file = gen_out });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
