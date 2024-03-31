const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    // Numeric types
    const num_gen_exe = b.addExecutable(.{
        .name = "numeric",
        .root_source_file = .{ .path = "codegen/numeric.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_num_gen_exe = b.addRunArtifact(num_gen_exe);
    const num_gen_out = run_num_gen_exe.addOutputFileArg("numeric.bin.z");

    // Letter case properties
    const case_prop_gen_exe = b.addExecutable(.{
        .name = "case_prop",
        .root_source_file = .{ .path = "codegen/case_prop.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_case_prop_gen_exe = b.addRunArtifact(case_prop_gen_exe);
    const case_prop_gen_out = run_case_prop_gen_exe.addOutputFileArg("case_prop.bin.z");

    // Uppercase mappings
    const upper_gen_exe = b.addExecutable(.{
        .name = "upper",
        .root_source_file = .{ .path = "codegen/upper.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_upper_gen_exe = b.addRunArtifact(upper_gen_exe);
    const upper_gen_out = run_upper_gen_exe.addOutputFileArg("upper.bin.z");

    // Lowercase mappings
    const lower_gen_exe = b.addExecutable(.{
        .name = "lower",
        .root_source_file = .{ .path = "codegen/lower.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_lower_gen_exe = b.addRunArtifact(lower_gen_exe);
    const lower_gen_out = run_lower_gen_exe.addOutputFileArg("lower.bin.z");

    const scripts_gen_exe = b.addExecutable(.{
        .name = "scripts",
        .root_source_file = .{ .path = "codegen/scripts.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_scripts_gen_exe = b.addRunArtifact(scripts_gen_exe);
    const scripts_gen_out = run_scripts_gen_exe.addOutputFileArg("scripts.bin.z");

    const core_gen_exe = b.addExecutable(.{
        .name = "core",
        .root_source_file = .{ .path = "codegen/core_props.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_core_gen_exe = b.addRunArtifact(core_gen_exe);
    const core_gen_out = run_core_gen_exe.addOutputFileArg("core_props.bin.z");

    const props_gen_exe = b.addExecutable(.{
        .name = "props",
        .root_source_file = .{ .path = "codegen/props.zig" },
        .target = b.host,
        .optimize = .Debug,
    });
    const run_props_gen_exe = b.addRunArtifact(props_gen_exe);
    const props_gen_out = run_props_gen_exe.addOutputFileArg("props.bin.z");

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
    const width_data = b.createModule(.{
        .root_source_file = .{ .path = "src/WidthData.zig" },
        .target = target,
        .optimize = optimize,
    });
    width_data.addAnonymousImport("dwp", .{ .root_source_file = dwp_gen_out });
    width_data.addImport("GraphemeData", grapheme_data);

    const display_width = b.addModule("DisplayWidth", .{
        .root_source_file = .{ .path = "src/DisplayWidth.zig" },
        .target = target,
        .optimize = optimize,
    });
    display_width.addImport("ascii", ascii);
    display_width.addImport("code_point", code_point);
    display_width.addImport("grapheme", grapheme);
    display_width.addImport("DisplayWidthData", width_data);

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

    const norm = b.addModule("Normalize", .{
        .root_source_file = .{ .path = "src/Normalize.zig" },
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

    // Case folding
    const fold_data = b.createModule(.{
        .root_source_file = .{ .path = "src/FoldData.zig" },
        .target = target,
        .optimize = optimize,
    });
    fold_data.addAnonymousImport("fold", .{ .root_source_file = fold_gen_out });

    const case_fold = b.addModule("CaseFold", .{
        .root_source_file = .{ .path = "src/CaseFold.zig" },
        .target = target,
        .optimize = optimize,
    });
    case_fold.addImport("ascii", ascii);
    case_fold.addImport("FoldData", fold_data);
    case_fold.addImport("Normalize", norm);

    // Letter case
    const case_data = b.addModule("CaseData", .{
        .root_source_file = .{ .path = "src/CaseData.zig" },
        .target = target,
        .optimize = optimize,
    });
    case_data.addImport("code_point", code_point);
    case_data.addAnonymousImport("case_prop", .{ .root_source_file = case_prop_gen_out });
    case_data.addAnonymousImport("upper", .{ .root_source_file = upper_gen_out });
    case_data.addAnonymousImport("lower", .{ .root_source_file = lower_gen_out });

    // Scripts
    const scripts_data = b.addModule("ScriptsData", .{
        .root_source_file = .{ .path = "src/ScriptsData.zig" },
        .target = target,
        .optimize = optimize,
    });
    scripts_data.addAnonymousImport("scripts", .{ .root_source_file = scripts_gen_out });

    // Properties
    const props_data = b.addModule("PropsData", .{
        .root_source_file = .{ .path = "src/PropsData.zig" },
        .target = target,
        .optimize = optimize,
    });
    props_data.addAnonymousImport("core_props", .{ .root_source_file = core_gen_out });
    props_data.addAnonymousImport("props", .{ .root_source_file = props_gen_out });
    props_data.addAnonymousImport("numeric", .{ .root_source_file = num_gen_out });

    // Unicode Tests
    const unicode_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/unicode_tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    unicode_tests.root_module.addImport("grapheme", grapheme);
    unicode_tests.root_module.addImport("Normalize", norm);

    const run_unicode_tests = b.addRunArtifact(unicode_tests);

    const unicode_test_step = b.step("unicode-test", "Run Unicode tests");
    unicode_test_step.dependOn(&run_unicode_tests.step);
}
