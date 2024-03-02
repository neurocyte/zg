const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    // const ziglyph = b.dependency("ziglyph", .{});

    // Code generation
    // Grapheme break
    const gbp_gen_exe = b.addExecutable(.{
        .name = "gbp",
        .root_source_file = .{ .path = "codegen/gbp.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_gbp_gen_exe = b.addRunArtifact(gbp_gen_exe);
    const gbp_gen_out = run_gbp_gen_exe.addOutputFileArg("gbp.bin.z");

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
    const dwp_gen_out = run_dwp_gen_exe.addOutputFileArg("dwp.bin.z");

    // Normalization properties
    const canon_gen_exe = b.addExecutable(.{
        .name = "canon",
        .root_source_file = .{ .path = "codegen/canon.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_canon_gen_exe = b.addRunArtifact(canon_gen_exe);
    const canon_gen_out = run_canon_gen_exe.addOutputFileArg("canon.bin.z");

    const compat_gen_exe = b.addExecutable(.{
        .name = "compat",
        .root_source_file = .{ .path = "codegen/compat.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_compat_gen_exe = b.addRunArtifact(compat_gen_exe);
    const compat_gen_out = run_compat_gen_exe.addOutputFileArg("compat.bin.z");

    const hangul_gen_exe = b.addExecutable(.{
        .name = "hangul",
        .root_source_file = .{ .path = "codegen/hangul.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_hangul_gen_exe = b.addRunArtifact(hangul_gen_exe);
    const hangul_gen_out = run_hangul_gen_exe.addOutputFileArg("hangul.bin.z");

    const normp_gen_exe = b.addExecutable(.{
        .name = "normp",
        .root_source_file = .{ .path = "codegen/normp.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_normp_gen_exe = b.addRunArtifact(normp_gen_exe);
    const normp_gen_out = run_normp_gen_exe.addOutputFileArg("normp.bin.z");

    const ccc_gen_exe = b.addExecutable(.{
        .name = "ccc",
        .root_source_file = .{ .path = "codegen/ccc.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_ccc_gen_exe = b.addRunArtifact(ccc_gen_exe);
    const ccc_gen_out = run_ccc_gen_exe.addOutputFileArg("ccc.bin.z");

    const gencat_gen_exe = b.addExecutable(.{
        .name = "gencat",
        .root_source_file = .{ .path = "codegen/gencat.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_gencat_gen_exe = b.addRunArtifact(gencat_gen_exe);
    const gencat_gen_out = run_gencat_gen_exe.addOutputFileArg("gencat.bin.z");

    const fold_gen_exe = b.addExecutable(.{
        .name = "fold",
        .root_source_file = .{ .path = "codegen/fold.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_fold_gen_exe = b.addRunArtifact(fold_gen_exe);
    const fold_gen_out = run_fold_gen_exe.addOutputFileArg("fold.bin.z");

    // Modules we provide
    // Code points
    const code_point = b.addModule("code_point", .{
        .root_source_file = .{ .path = "src/code_point.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Grapheme clusters
    const grapheme_data = b.createModule(.{
        .root_source_file = .{ .path = "src/GraphemeData.zig" },
        .target = target,
        .optimize = optimize,
    });
    grapheme_data.addAnonymousImport("gbp", .{ .root_source_file = gbp_gen_out });

    const grapheme = b.addModule("grapheme", .{
        .root_source_file = .{ .path = "src/grapheme.zig" },
        .target = target,
        .optimize = optimize,
    });
    grapheme.addImport("code_point", code_point);
    grapheme.addImport("GraphemeData", grapheme_data);

    // ASCII utilities
    const ascii = b.addModule("ascii", .{
        .root_source_file = .{ .path = "src/ascii.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Fixed pitch font display width
    const dw_data = b.createModule(.{
        .root_source_file = .{ .path = "src/WidthData.zig" },
        .target = target,
        .optimize = optimize,
    });
    dw_data.addAnonymousImport("dwp", .{ .root_source_file = dwp_gen_out });
    dw_data.addImport("GraphemeData", grapheme_data);

    const display_width = b.addModule("DisplayWidth", .{
        .root_source_file = .{ .path = "src/DisplayWidth.zig" },
        .target = target,
        .optimize = optimize,
    });
    display_width.addImport("ascii", ascii);
    display_width.addImport("code_point", code_point);
    display_width.addImport("grapheme", grapheme);
    display_width.addImport("DisplayWidthData", dw_data);

    // Normalization
    const ccc_data = b.createModule(.{
        .root_source_file = .{ .path = "src/CombiningData.zig" },
        .target = target,
        .optimize = optimize,
    });
    ccc_data.addAnonymousImport("ccc", .{ .root_source_file = ccc_gen_out });

    const canon_data = b.createModule(.{
        .root_source_file = .{ .path = "src/CanonData.zig" },
        .target = target,
        .optimize = optimize,
    });
    canon_data.addAnonymousImport("canon", .{ .root_source_file = canon_gen_out });

    const compat_data = b.createModule(.{
        .root_source_file = .{ .path = "src/CompatData.zig" },
        .target = target,
        .optimize = optimize,
    });
    compat_data.addAnonymousImport("compat", .{ .root_source_file = compat_gen_out });

    const hangul_data = b.createModule(.{
        .root_source_file = .{ .path = "src/HangulData.zig" },
        .target = target,
        .optimize = optimize,
    });
    hangul_data.addAnonymousImport("hangul", .{ .root_source_file = hangul_gen_out });

    const normp_data = b.createModule(.{
        .root_source_file = .{ .path = "src/NormPropsData.zig" },
        .target = target,
        .optimize = optimize,
    });
    normp_data.addAnonymousImport("normp", .{ .root_source_file = normp_gen_out });

    const norm_data = b.createModule(.{
        .root_source_file = .{ .path = "src/NormData.zig" },
        .target = target,
        .optimize = optimize,
    });
    norm_data.addImport("CanonData", canon_data);
    norm_data.addImport("CombiningData", ccc_data);
    norm_data.addImport("CompatData", compat_data);
    norm_data.addImport("HangulData", hangul_data);
    norm_data.addImport("NormPropsData", normp_data);

    const norm = b.addModule("Normalizer", .{
        .root_source_file = .{ .path = "src/Normalizer.zig" },
        .target = target,
        .optimize = optimize,
    });
    norm.addImport("ascii", ascii);
    norm.addImport("code_point", code_point);
    norm.addImport("NormData", norm_data);

    // General Category
    const gencat_data = b.addModule("GenCatData", .{
        .root_source_file = .{ .path = "src/GenCatData.zig" },
        .target = target,
        .optimize = optimize,
    });
    gencat_data.addAnonymousImport("gencat", .{ .root_source_file = gencat_gen_out });

    // Case
    const fold_data = b.createModule(.{
        .root_source_file = .{ .path = "src/FoldData.zig" },
        .target = target,
        .optimize = optimize,
    });
    fold_data.addAnonymousImport("fold", .{ .root_source_file = fold_gen_out });

    const caser = b.addModule("Caser", .{
        .root_source_file = .{ .path = "src/Caser.zig" },
        .target = target,
        .optimize = optimize,
    });
    caser.addImport("ascii", ascii);
    caser.addImport("FoldData", fold_data);
    caser.addImport("Normalizer", norm);

    // Benchmark rig
    const exe = b.addExecutable(.{
        .name = "zg",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    // exe.root_module.addImport("ascii", ascii);
    // exe.root_module.addImport("code_point", code_point);
    // exe.root_module.addImport("grapheme", grapheme);
    // exe.root_module.addImport("DisplayWidth", display_width);
    exe.root_module.addImport("Normalizer", norm);
    // exe.root_module.addImport("Caser", caser);
    // exe.root_module.addImport("GenCatData", gencat_data);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/Caser.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("ascii", ascii);
    // exe_unit_tests.root_module.addImport("code_point", code_point);
    // exe_unit_tests.root_module.addImport("GraphemeData", grapheme_data);
    // exe_unit_tests.root_module.addImport("grapheme", grapheme);
    // exe_unit_tests.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));
    // exe_unit_tests.root_module.addAnonymousImport("normp", .{ .root_source_file = normp_gen_out });
    // exe_unit_tests.root_module.addImport("DisplayWidthData", dw_data);
    exe_unit_tests.root_module.addImport("NormData", norm_data);
    exe_unit_tests.root_module.addImport("Normalizer", norm);
    exe_unit_tests.root_module.addImport("FoldData", fold_data);
    // exe_unit_tests.filter = "nfd !ASCII";

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
