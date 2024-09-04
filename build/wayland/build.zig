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
        .optimize = .ReleaseFast,
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

    const config_header = b.addConfigHeader(.{
        .style = .blank,
        .include_path = "config.h",
    }, .{
        .PACKAGE = "wayland",
        .PACKAGE_VERSION = "1.22.0",
        .HAVE_SYS_PRCTL_H = 1,
        .HAVE_SYS_PROCTL_H = 1,
        .HAVE_SYS_UCRED_H = 1,
        // TODO: more here from wayland/meson.build
    });

    const wayland_scanner = b.addExecutable(.{
        .name = "wayland-scanner",
        .target = b.host,
        .optimize = .ReleaseFast,
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

    const wayland_private = b.addStaticLibrary(.{
        .name = "wayland-private",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = wayland_private;
        lib.addIncludePath(wayland_dep.path("src"));
        lib.addCSourceFiles(.{
            .root = wayland_dep.path(""),
            .files = &.{
                "src/connection.c",
                "src/wayland-os.c",
            },
            .flags = &.{},
        });
        lib.linkLibC();
        // dependencies: [ epoll_dep, ffi_dep, rt_dep ]
        lib.linkSystemLibrary("ffi");

        lib.addConfigHeader(b.addConfigHeader(.{
            .style = .blank,
            .include_path = "../config.h",
        }, .{
            .PACKAGE = "wayland",
            .PACKAGE_VERSION = "1.22.0",
            .HAVE_SYS_PRCTL_H = 1,
            .HAVE_SYS_PROCTL_H = 1,
            // .HAVE_SYS_UCRED_H = 1,
        }));

        b.installArtifact(lib);
    }

    const wayland_util = b.addStaticLibrary(.{
        .name = "wayland-util",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = wayland_util;
        lib.addCSourceFiles(.{
            .root = wayland_dep.path(""),
            .files = &.{
                "src/wayland-util.c",
            },
            .flags = &.{},
        });
        lib.linkLibC();

        b.installArtifact(lib);
    }

    const wayland_client = b.addSharedLibrary(.{
        .name = "wayland-client",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = wayland_client;
        lib.addIncludePath(wayland_dep.path("src"));
        lib.addCSourceFiles(.{
            .root = wayland_dep.path(""),
            .files = &.{
                "src/wayland-client.c",
                "src/wayland-util.c",

                // wut?
                "src/wayland-server.c",
                "src/event-loop.c",
            },
            .flags = &.{},
        });
        lib.linkLibC();
        lib.linkLibrary(wayland_private);

        // wayland_client_protocol_h,
        const wayland_headers = b.addWriteFiles();
        {
            const generate_header = b.addRunArtifact(wayland_scanner);
            generate_header.addArg("client-header");
            generate_header.addFileArg(wayland_dep.path("protocol/wayland.xml"));
            const header_filename = "wayland-client-protocol.h";
            const header = generate_header.addOutputFileArg(header_filename);
            _ = wayland_headers.addCopyFile(header, header_filename);
        }
        // wayland_client_protocol_core_h,
        {
            const generate_header = b.addRunArtifact(wayland_scanner);
            generate_header.addArgs(&.{ "client-header", "-c" });
            generate_header.addFileArg(wayland_dep.path("protocol/wayland.xml"));
            const header_filename = "wayland-client-protocol-core.h";
            const header = generate_header.addOutputFileArg(header_filename);
            _ = wayland_headers.addCopyFile(header, header_filename);
        }
        lib.addIncludePath(wayland_headers.getDirectory());

        // wayland_protocol_c,
        {
            const generate = b.addRunArtifact(wayland_scanner);
            generate.addArgs(&.{ "-s", "public-code" });
            generate.addFileArg(wayland_dep.path("protocol/wayland.xml"));
            const source = generate.addOutputFileArg("wayland-protocol.c");

            lib.addCSourceFile(.{ .file = source, .flags = &.{} });
        }

        b.installArtifact(lib);
    }

    const wayland_server = b.addStaticLibrary(.{
        .name = "wayland-server",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = wayland_server;
        lib.addIncludePath(wayland_dep.path("src"));
        lib.addCSourceFiles(.{
            .root = wayland_dep.path(""),
            .files = &.{
                "src/wayland-server.c",
                "src/wayland-shm.c",
                "src/event-loop.c",
            },
            .flags = &.{},
        });
        lib.linkLibC();
        lib.linkLibrary(wayland_private);
        lib.linkLibrary(wayland_util);
        lib.addConfigHeader(config_header);

        // wayland_server_protocol_h,
        const wayland_headers = b.addWriteFiles();
        {
            const generate_header = b.addRunArtifact(wayland_scanner);
            generate_header.addArg("server-header");
            generate_header.addFileArg(wayland_dep.path("protocol/wayland.xml"));
            const header_filename = "wayland-server-protocol.h";
            const header = generate_header.addOutputFileArg(header_filename);
            _ = wayland_headers.addCopyFile(header, header_filename);
        }
        // wayland_server_protocol_core_h,
        {
            const generate_header = b.addRunArtifact(wayland_scanner);
            generate_header.addArgs(&.{ "server-header", "-c" });
            generate_header.addFileArg(wayland_dep.path("protocol/wayland.xml"));
            const header_filename = "wayland-server-protocol-core.h";
            const header = generate_header.addOutputFileArg(header_filename);
            _ = wayland_headers.addCopyFile(header, header_filename);
        }
        lib.addIncludePath(wayland_headers.getDirectory());

        // wayland_protocol_c,
        {
            const generate = b.addRunArtifact(wayland_scanner);
            generate.addArgs(&.{ "-s", "public-code" });
            generate.addFileArg(wayland_dep.path("protocol/wayland.xml"));
            const source = generate.addOutputFileArg("wayland-protocol.c");

            lib.addCSourceFile(.{ .file = source, .flags = &.{} });
        }

        b.installArtifact(lib);
    }

    const wayland_egl = b.addSharedLibrary(.{
        .name = "wayland-egl",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = wayland_egl;
        lib.addIncludePath(wayland_dep.path("egl"));
        lib.addCSourceFiles(.{
            .root = wayland_dep.path("egl"),
            .files = &.{
                "wayland-egl.c",
            },
            .flags = &.{},
        });
        lib.linkLibC();
        // lib.linkLibrary(wayland_client);

        b.installArtifact(lib);
    }

    const wayland_cursor = b.addSharedLibrary(.{
        .name = "wayland-cursor",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = wayland_cursor;
        lib.addIncludePath(wayland_dep.path("cursor"));
        lib.addCSourceFiles(.{
            .root = wayland_dep.path("cursor"),
            .files = &.{
                "wayland-cursor.c",
                "os-compatibility.c",
                "xcursor.c",
            },
            .flags = &.{},
        });
        lib.linkLibC();
        // lib.linkLibrary(wayland_client);
        lib.addConfigHeader(config_header);

        b.installArtifact(lib);
    }

    //--

    const test_runner = b.addStaticLibrary(.{
        .name = "test-runner",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = test_runner;
        lib.addIncludePath(wayland_dep.path("src"));
        lib.addCSourceFiles(.{
            .root = wayland_dep.path("tests"),
            .files = &.{
                "test-runner.c",
                "test-helpers.c",
                "test-compositor.c",
            },
            .flags = &.{},
        });
        lib.linkLibC();
        lib.linkLibrary(wayland_util);
        lib.linkLibrary(wayland_private);
        lib.linkLibrary(wayland_client);
        lib.linkLibrary(wayland_server);
        lib.addConfigHeader(config_header);

        b.installArtifact(lib);
    }

    const leak_checker = b.addExecutable(.{
        .name = "exec-fd-leak-checker",
        .target = target,
        .optimize = optimize,
    });
    {
        const exe = leak_checker;
        exe.addCSourceFiles(.{
            .root = wayland_dep.path("tests"),
            .files = &.{
                "exec-fd-leak-checker.c",
                "test-helpers.c",
            },
            .flags = &.{},
        });
        exe.linkLibC();
        exe.addConfigHeader(config_header);

        b.installArtifact(exe);
    }

    const test_step = b.step("test", "");

    const tests = [_][]const u8{
        "array-test",
        "client-test",
        "compositor-introspection-test",
        "connection-test",
        "event-loop-test",
        "fixed-test",
        "interface-test",
        "list-test",
        "map-test",
        "message-test",
        // "os-wrappers-test",
        "protocol-logger-test",
        "queue-test",
        "resources-test",
        "sanity-test",
        "signal-test",
        "socket-test",
    };
    for (tests) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFile(.{
            .file = wayland_dep.path(b.fmt("tests/{s}.c", .{name})),
            .flags = &.{},
        });
        exe.addIncludePath(wayland_dep.path("src"));
        exe.linkLibrary(test_runner);

        const run = b.addRunArtifact(exe);
        run.step.dependOn(&leak_checker.step);
        // TODO: don't hard-code this, use exe.getEmittedBinDirectory()
        run.setEnvironmentVariable("TEST_BUILD_DIR", "zig-out/bin");

        const step = b.step(name, "");
        step.dependOn(&run.step);

        test_step.dependOn(step);
    }
}
