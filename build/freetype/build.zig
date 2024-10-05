// SPDX-FileCopyrightText: © 2024 Mark Delk <jethrodaniel@gmail.com>
//
// SPDX-License-Identifier: Zlib

const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const freetype_dep = b.dependency("freetype", .{});

    //

    const lib = b.addStaticLibrary(.{
        .name = "freetype",
        .target = target,
        .optimize = optimize,
        .strip = true,
    });
    {
        if (optimize != .Debug) {
            lib.defineCMacro("NDEBUG", "1");
            lib.defineCMacro("__FILE__", "\"__FILE__\"");
            lib.defineCMacro("__LINE__", "0");
        }

        lib.addCSourceFiles(.{
            .root = freetype_dep.path(""),
            .files = &.{
                "src/autofit/autofit.c",
                "src/base/ftbase.c",
                "src/base/ftbbox.c",
                "src/base/ftbdf.c",
                "src/base/ftbitmap.c",
                "src/base/ftcid.c",
                "src/base/ftfstype.c",
                "src/base/ftgasp.c",
                "src/base/ftglyph.c",
                "src/base/ftgxval.c",
                "src/base/ftinit.c",
                "src/base/ftmm.c",
                "src/base/ftotval.c",
                "src/base/ftpatent.c",
                "src/base/ftpfr.c",
                "src/base/ftstroke.c",
                "src/base/ftsynth.c",
                "src/base/fttype1.c",
                "src/base/ftwinfnt.c",
                "src/bdf/bdf.c",
                "src/bzip2/ftbzip2.c",
                "src/cache/ftcache.c",
                "src/cff/cff.c",
                "src/cid/type1cid.c",
                "src/gzip/ftgzip.c",
                "src/lzw/ftlzw.c",
                "src/pcf/pcf.c",
                "src/pfr/pfr.c",
                "src/psaux/psaux.c",
                "src/pshinter/pshinter.c",
                "src/psnames/psnames.c",
                "src/raster/raster.c",
                "src/sdf/sdf.c",
                "src/sfnt/sfnt.c",
                "src/smooth/smooth.c",
                "src/svg/svg.c",
                "src/truetype/truetype.c",
                "src/type1/type1.c",
                "src/type42/type42.c",
                "src/winfonts/winfnt.c",
            },
            .flags = &.{},
        });

        lib.defineCMacro("FT2_BUILD_LIBRARY", "1");
        lib.defineCMacro("HAVE_UNISTD_H", "");
        lib.defineCMacro("HAVE_FCNTL_H", "");

        switch (target.result.os.tag) {
            .windows => {
                lib.addCSourceFiles(.{
                    .root = freetype_dep.path(""),
                    .files = &.{
                        "builds/windows/ftsystem.c",
                        "builds/windows/ftdebug.c",
                    },
                    .flags = &.{},
                });
                lib.addWin32ResourceFile(.{
                    .file = freetype_dep.path("src/base/ftver.rc"),
                });
            },
            else => {
                lib.addCSourceFiles(.{
                    .root = freetype_dep.path(""),
                    .files = &.{
                        // TODO: do we need this "unix" one?
                        // "builds/unix/ftsystem.c",
                        "src/base/ftsystem.c",
                        "src/base/ftdebug.c",
                    },
                    .flags = &.{},
                });
            },
        }

        lib.addIncludePath(freetype_dep.path("include"));
        lib.installHeader(freetype_dep.path("include/ft2build.h"), "ft2build.h");
        lib.installHeadersDirectory(freetype_dep.path("include/freetype"), "freetype", .{});

        if (target.result.os.tag == .macos) {
            const sdk = std.zig.system.darwin.getSdk(b.allocator, b.host.result) orelse
                @panic("macOS SDK is missing");
            lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
            lib.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
            lib.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
        }
        lib.linkLibC();

        b.installArtifact(lib);
    }
}
