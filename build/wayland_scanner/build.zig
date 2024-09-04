// SPDX-FileCopyrightText: © 2024 Mark Delk <jethrodaniel@gmail.com>
//
// SPDX-License-Identifier: Zlib

const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wayland_dep = b.dependency("wayland", .{});
    const expat_dep = b.dependency("expat", .{});

    //

    const expat = b.addStaticLibrary(.{
        .name = "expat",
        .target = b.host,
        .optimize = optimize,
    });
    {
        expat.addIncludePath(expat_dep.path("expat/lib"));
        expat.addCSourceFiles(.{
            .root = expat_dep.path("expat/lib"),
            .files = &.{
                "xmlparse.c",
                "xmlrole.c",
                "xmltok.c",
            },
            .flags = &.{"-std=c99"},
        });
        expat.linkLibC();
        expat.addConfigHeader(b.addConfigHeader(.{
            .style = .{ .cmake = expat_dep.path("expat/expat_config.h.cmake") },
            .include_path = "expat_config.h",
        }, .{
            .HAVE_STDLIB_H = 1,
            .HAVE_STRINGS_H = 1,
            .HAVE_STRING_H = 1,
            .HAVE_UNISTD_H = @intFromBool(target.result.os.tag == .linux),
            .PACKAGE = "expat",
            .PACKAGE_BUGREPORT = "https://github.com/libexpat/libexpat/issues",
            .PACKAGE_NAME = "expat",
            .PACKAGE_STRING = "expat 2.6.1",
            .PACKAGE_TARNAME = "expat",
            .PACKAGE_URL = "https://libexpat.github.io/",
            .PACKAGE_VERSION = "2.6.1",
            .STDC_HEADERS = 1,
            .XML_ATTR_INFO = 1,
            .XML_CONTEXT_BYTES = 1024,
            .XML_DEV_URANDOM = @intFromBool(target.result.os.tag != .windows),
            .XML_DTD = 1,
            .XML_GE = 1,
            .XML_NS = 1,
        }));
        expat.installHeadersDirectory(expat_dep.path("expat/lib"), "", .{});
    }

    const version_header = b.addConfigHeader(.{
        .style = .{ .cmake = wayland_dep.path("src/wayland-version.h.in") },
        .include_path = "wayland-version.h",
    }, .{
        .WAYLAND_VERSION_MAJOR = 1,
        .WAYLAND_VERSION_MINOR = 22,
        .WAYLAND_VERSION_MICRO = 0,
        .WAYLAND_VERSION = "1.22.0",
    });

    const wayland_scanner = b.addExecutable(.{
        .name = "wayland-scanner",
        .target = b.host,
        .optimize = optimize,
    });
    {
        const exe = wayland_scanner;
        exe.addIncludePath(wayland_dep.path("include"));
        exe.addCSourceFiles(.{
            .root = wayland_dep.path(""),
            .files = &.{
                "src/scanner.c",
                "src/wayland-util.c",
            },
            .flags = &.{},
        });
        exe.addConfigHeader(version_header);
        exe.linkLibC();
        exe.linkLibrary(expat);

        b.installArtifact(exe);
    }
}
