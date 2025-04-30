const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Code generation
    // Grapheme break
    const gbp_gen_exe = b.addExecutable(.{
        .name = "gbp",
        .root_source_file = b.path("codegen/gbp.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_gbp_gen_exe = b.addRunArtifact(gbp_gen_exe);
    const gbp_gen_out = run_gbp_gen_exe.addOutputFileArg("gbp.bin.z");

    // Display width
    const cjk = b.option(bool, "cjk", "Ambiguous code points are wide (display width: 2).") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "cjk", cjk);

    // Visible Controls
    const c0_width = b.option(
        i4,
        "c0_width",
        "C0 controls have this width (default: 0, <BS> <Del> default -1)",
    );
    options.addOption(?i4, "c0_width", c0_width);
    const c1_width = b.option(
        i4,
        "c1_width",
        "C1 controls have this width (default: 0)",
    );
    options.addOption(?i4, "c1_width", c1_width);

    const dwp_gen_exe = b.addExecutable(.{
        .name = "dwp",
        .root_source_file = b.path("codegen/dwp.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    dwp_gen_exe.root_module.addOptions("options", options);
    const run_dwp_gen_exe = b.addRunArtifact(dwp_gen_exe);
    const dwp_gen_out = run_dwp_gen_exe.addOutputFileArg("dwp.bin.z");

    // Normalization properties
    const canon_gen_exe = b.addExecutable(.{
        .name = "canon",
        .root_source_file = b.path("codegen/canon.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_canon_gen_exe = b.addRunArtifact(canon_gen_exe);
    const canon_gen_out = run_canon_gen_exe.addOutputFileArg("canon.bin.z");

    const compat_gen_exe = b.addExecutable(.{
        .name = "compat",
        .root_source_file = b.path("codegen/compat.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_compat_gen_exe = b.addRunArtifact(compat_gen_exe);
    const compat_gen_out = run_compat_gen_exe.addOutputFileArg("compat.bin.z");

    const hangul_gen_exe = b.addExecutable(.{
        .name = "hangul",
        .root_source_file = b.path("codegen/hangul.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_hangul_gen_exe = b.addRunArtifact(hangul_gen_exe);
    const hangul_gen_out = run_hangul_gen_exe.addOutputFileArg("hangul.bin.z");

    const normp_gen_exe = b.addExecutable(.{
        .name = "normp",
        .root_source_file = b.path("codegen/normp.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_normp_gen_exe = b.addRunArtifact(normp_gen_exe);
    const normp_gen_out = run_normp_gen_exe.addOutputFileArg("normp.bin.z");

    const ccc_gen_exe = b.addExecutable(.{
        .name = "ccc",
        .root_source_file = b.path("codegen/ccc.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_ccc_gen_exe = b.addRunArtifact(ccc_gen_exe);
    const ccc_gen_out = run_ccc_gen_exe.addOutputFileArg("ccc.bin.z");

    const gencat_gen_exe = b.addExecutable(.{
        .name = "gencat",
        .root_source_file = b.path("codegen/gencat.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_gencat_gen_exe = b.addRunArtifact(gencat_gen_exe);
    const gencat_gen_out = run_gencat_gen_exe.addOutputFileArg("gencat.bin.z");

    const fold_gen_exe = b.addExecutable(.{
        .name = "fold",
        .root_source_file = b.path("codegen/fold.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_fold_gen_exe = b.addRunArtifact(fold_gen_exe);
    const fold_gen_out = run_fold_gen_exe.addOutputFileArg("fold.bin.z");

    // Numeric types
    const num_gen_exe = b.addExecutable(.{
        .name = "numeric",
        .root_source_file = b.path("codegen/numeric.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_num_gen_exe = b.addRunArtifact(num_gen_exe);
    const num_gen_out = run_num_gen_exe.addOutputFileArg("numeric.bin.z");

    // Letter case properties
    const case_prop_gen_exe = b.addExecutable(.{
        .name = "case_prop",
        .root_source_file = b.path("codegen/case_prop.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_case_prop_gen_exe = b.addRunArtifact(case_prop_gen_exe);
    const case_prop_gen_out = run_case_prop_gen_exe.addOutputFileArg("case_prop.bin.z");

    // Uppercase mappings
    const upper_gen_exe = b.addExecutable(.{
        .name = "upper",
        .root_source_file = b.path("codegen/upper.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_upper_gen_exe = b.addRunArtifact(upper_gen_exe);
    const upper_gen_out = run_upper_gen_exe.addOutputFileArg("upper.bin.z");

    // Lowercase mappings
    const lower_gen_exe = b.addExecutable(.{
        .name = "lower",
        .root_source_file = b.path("codegen/lower.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_lower_gen_exe = b.addRunArtifact(lower_gen_exe);
    const lower_gen_out = run_lower_gen_exe.addOutputFileArg("lower.bin.z");

    const scripts_gen_exe = b.addExecutable(.{
        .name = "scripts",
        .root_source_file = b.path("codegen/scripts.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_scripts_gen_exe = b.addRunArtifact(scripts_gen_exe);
    const scripts_gen_out = run_scripts_gen_exe.addOutputFileArg("scripts.bin.z");

    const core_gen_exe = b.addExecutable(.{
        .name = "core",
        .root_source_file = b.path("codegen/core_props.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_core_gen_exe = b.addRunArtifact(core_gen_exe);
    const core_gen_out = run_core_gen_exe.addOutputFileArg("core_props.bin.z");

    const props_gen_exe = b.addExecutable(.{
        .name = "props",
        .root_source_file = b.path("codegen/props.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const run_props_gen_exe = b.addRunArtifact(props_gen_exe);
    const props_gen_out = run_props_gen_exe.addOutputFileArg("props.bin.z");

    // Modules we provide
    // Code points
    const code_point = b.addModule("code_point", .{
        .root_source_file = b.path("src/code_point.zig"),
        .target = target,
        .optimize = optimize,
    });

    const code_point_t = b.addTest(.{
        .name = "code_point",
        .root_module = code_point,
        .target = target,
        .optimize = optimize,
    });
    const code_point_tr = b.addRunArtifact(code_point_t);

    // Graphemes
    const graphemes = b.addModule("Graphemes", .{
        .root_source_file = b.path("src/Graphemes.zig"),
        .target = target,
        .optimize = optimize,
    });
    graphemes.addAnonymousImport("gbp", .{ .root_source_file = gbp_gen_out });
    graphemes.addImport("code_point", code_point);

    const grapheme_t = b.addTest(.{
        .name = "Graphemes",
        .root_module = graphemes,
        .target = target,
        .optimize = optimize,
    });
    const grapheme_tr = b.addRunArtifact(grapheme_t);

    // ASCII utilities
    const ascii = b.addModule("ascii", .{
        .root_source_file = b.path("src/ascii.zig"),
        .target = target,
        .optimize = optimize,
    });

    const ascii_t = b.addTest(.{
        .name = "ascii",
        .root_module = ascii,
        .target = target,
        .optimize = optimize,
    });
    const ascii_tr = b.addRunArtifact(ascii_t);

    // Fixed pitch font display width
    const display_width = b.addModule("DisplayWidth", .{
        .root_source_file = b.path("src/DisplayWidth.zig"),
        .target = target,
        .optimize = optimize,
    });
    display_width.addAnonymousImport("dwp", .{ .root_source_file = dwp_gen_out });
    display_width.addImport("ascii", ascii);
    display_width.addImport("code_point", code_point);
    display_width.addImport("Graphemes", graphemes);
    display_width.addOptions("options", options); // For testing

    const display_width_t = b.addTest(.{
        .name = "display_width",
        .root_module = display_width,
        .target = target,
        .optimize = optimize,
    });
    const display_width_tr = b.addRunArtifact(display_width_t);

    // Normalization
    const ccc_data = b.createModule(.{
        .root_source_file = b.path("src/CombiningData.zig"),
        .target = target,
        .optimize = optimize,
    });
    ccc_data.addAnonymousImport("ccc", .{ .root_source_file = ccc_gen_out });

    const ccc_data_t = b.addTest(.{
        .name = "ccc_data",
        .root_module = ccc_data,
        .target = target,
        .optimize = optimize,
    });
    const ccc_data_tr = b.addRunArtifact(ccc_data_t);

    const canon_data = b.createModule(.{
        .root_source_file = b.path("src/CanonData.zig"),
        .target = target,
        .optimize = optimize,
    });
    canon_data.addAnonymousImport("canon", .{ .root_source_file = canon_gen_out });

    const canon_data_t = b.addTest(.{
        .name = "canon_data",
        .root_module = canon_data,
        .target = target,
        .optimize = optimize,
    });
    const canon_data_tr = b.addRunArtifact(canon_data_t);

    const compat_data = b.createModule(.{
        .root_source_file = b.path("src/CompatData.zig"),
        .target = target,
        .optimize = optimize,
    });
    compat_data.addAnonymousImport("compat", .{ .root_source_file = compat_gen_out });

    const compat_data_t = b.addTest(.{
        .name = "compat_data",
        .root_module = compat_data,
        .target = target,
        .optimize = optimize,
    });
    const compat_data_tr = b.addRunArtifact(compat_data_t);

    const hangul_data = b.createModule(.{
        .root_source_file = b.path("src/HangulData.zig"),
        .target = target,
        .optimize = optimize,
    });
    hangul_data.addAnonymousImport("hangul", .{ .root_source_file = hangul_gen_out });

    const hangul_data_t = b.addTest(.{
        .name = "hangul_data",
        .root_module = hangul_data,
        .target = target,
        .optimize = optimize,
    });
    const hangul_data_tr = b.addRunArtifact(hangul_data_t);

    const normp_data = b.createModule(.{
        .root_source_file = b.path("src/NormPropsData.zig"),
        .target = target,
        .optimize = optimize,
    });
    normp_data.addAnonymousImport("normp", .{ .root_source_file = normp_gen_out });

    const normp_data_t = b.addTest(.{
        .name = "normp_data",
        .root_module = normp_data,
        .target = target,
        .optimize = optimize,
    });
    const normp_data_tr = b.addRunArtifact(normp_data_t);

    const norm_data = b.createModule(.{
        .root_source_file = b.path("src/NormData.zig"),
        .target = target,
        .optimize = optimize,
    });
    norm_data.addImport("CanonData", canon_data);
    norm_data.addImport("CombiningData", ccc_data);
    norm_data.addImport("CompatData", compat_data);
    norm_data.addImport("HangulData", hangul_data);
    norm_data.addImport("NormPropsData", normp_data);

    const norm_data_t = b.addTest(.{
        .name = "norm_data",
        .root_module = norm_data,
        .target = target,
        .optimize = optimize,
    });
    const norm_data_tr = b.addRunArtifact(norm_data_t);

    const norm = b.addModule("Normalize", .{
        .root_source_file = b.path("src/Normalize.zig"),
        .target = target,
        .optimize = optimize,
    });
    norm.addImport("ascii", ascii);
    norm.addImport("code_point", code_point);
    norm.addImport("NormData", norm_data);

    const norm_t = b.addTest(.{
        .name = "norm",
        .root_module = norm,
        .target = target,
        .optimize = optimize,
    });
    const norm_tr = b.addRunArtifact(norm_t);

    // General Category
    const gencat_data = b.addModule("GenCatData", .{
        .root_source_file = b.path("src/GenCatData.zig"),
        .target = target,
        .optimize = optimize,
    });
    gencat_data.addAnonymousImport("gencat", .{ .root_source_file = gencat_gen_out });

    const gencat_data_t = b.addTest(.{
        .name = "gencat_data",
        .root_module = gencat_data,
        .target = target,
        .optimize = optimize,
    });
    const gencat_data_tr = b.addRunArtifact(gencat_data_t);

    // Case folding
    const fold_data = b.createModule(.{
        .root_source_file = b.path("src/FoldData.zig"),
        .target = target,
        .optimize = optimize,
    });
    fold_data.addAnonymousImport("fold", .{ .root_source_file = fold_gen_out });

    const case_fold = b.addModule("CaseFold", .{
        .root_source_file = b.path("src/CaseFold.zig"),
        .target = target,
        .optimize = optimize,
    });
    case_fold.addImport("ascii", ascii);
    case_fold.addImport("FoldData", fold_data);
    case_fold.addImport("Normalize", norm);

    const case_fold_t = b.addTest(.{
        .name = "case_fold",
        .root_module = case_fold,
        .target = target,
        .optimize = optimize,
    });
    const case_fold_tr = b.addRunArtifact(case_fold_t);

    // Letter case
    const case_data = b.addModule("CaseData", .{
        .root_source_file = b.path("src/CaseData.zig"),
        .target = target,
        .optimize = optimize,
    });
    case_data.addImport("code_point", code_point);
    case_data.addAnonymousImport("case_prop", .{ .root_source_file = case_prop_gen_out });
    case_data.addAnonymousImport("upper", .{ .root_source_file = upper_gen_out });
    case_data.addAnonymousImport("lower", .{ .root_source_file = lower_gen_out });

    const case_data_t = b.addTest(.{
        .name = "case_data",
        .root_module = case_data,
        .target = target,
        .optimize = optimize,
    });
    const case_data_tr = b.addRunArtifact(case_data_t);

    // Scripts
    const scripts_data = b.addModule("ScriptsData", .{
        .root_source_file = b.path("src/ScriptsData.zig"),
        .target = target,
        .optimize = optimize,
    });
    scripts_data.addAnonymousImport("scripts", .{ .root_source_file = scripts_gen_out });

    const scripts_data_t = b.addTest(.{
        .name = "scripts_data",
        .root_module = scripts_data,
        .target = target,
        .optimize = optimize,
    });
    const scripts_data_tr = b.addRunArtifact(scripts_data_t);

    // Properties
    const props_data = b.addModule("PropsData", .{
        .root_source_file = b.path("src/PropsData.zig"),
        .target = target,
        .optimize = optimize,
    });
    props_data.addAnonymousImport("core_props", .{ .root_source_file = core_gen_out });
    props_data.addAnonymousImport("props", .{ .root_source_file = props_gen_out });
    props_data.addAnonymousImport("numeric", .{ .root_source_file = num_gen_out });

    const props_data_t = b.addTest(.{
        .name = "props_data",
        .root_module = props_data,
        .target = target,
        .optimize = optimize,
    });
    const props_data_tr = b.addRunArtifact(props_data_t);

    // Unicode Tests
    const unicode_tests = b.addTest(.{
        .root_source_file = b.path("src/unicode_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    unicode_tests.root_module.addImport("Graphemes", graphemes);
    unicode_tests.root_module.addImport("Normalize", norm);

    const run_unicode_tests = b.addRunArtifact(unicode_tests);

    const test_step = b.step("test", "Run all module tests");
    test_step.dependOn(&run_unicode_tests.step);
    test_step.dependOn(&code_point_tr.step);
    test_step.dependOn(&display_width_tr.step);
    test_step.dependOn(&grapheme_tr.step);
    test_step.dependOn(&ascii_tr.step);
    test_step.dependOn(&ccc_data_tr.step);
    test_step.dependOn(&canon_data_tr.step);
    test_step.dependOn(&compat_data_tr.step);
    test_step.dependOn(&hangul_data_tr.step);
    test_step.dependOn(&normp_data_tr.step);
    test_step.dependOn(&norm_data_tr.step);
    test_step.dependOn(&norm_tr.step);
    test_step.dependOn(&gencat_data_tr.step);
    test_step.dependOn(&case_fold_tr.step);
    test_step.dependOn(&case_data_tr.step);
    test_step.dependOn(&scripts_data_tr.step);
    test_step.dependOn(&props_data_tr.step);
}
