// SPDX-FileCopyrightText: © 2024 Mark Delk <jethrodaniel@gmail.com>
//
// SPDX-License-Identifier: Zlib

const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_dep = b.dependency("sdl", .{});
    const sdl_ttf_dep = b.dependency("sdl_ttf", .{});
    const freetype_dep = b.dependency("freetype", .{});
    const wayland_dep = b.dependency("wayland", .{});

    //

    const lib = b.addStaticLibrary(.{
        .name = "SDL3",
        .target = target,
        .optimize = optimize,
    });
    {
        lib.addIncludePath(sdl_dep.path("src"));
        lib.addIncludePath(sdl_dep.path("include"));
        lib.addIncludePath(sdl_dep.path("include/SDL3"));
        lib.addIncludePath(sdl_dep.path("include/build_config"));

        lib.addCSourceFiles(.{
            .root = sdl_dep.path(""),
            .files = &generic_src_files,
            .flags = &.{},
        });

        const SDL_ASSERT_LEVEL: u8 = switch (optimize) {
            .ReleaseFast, .ReleaseSmall => 1,
            .ReleaseSafe, .Debug => 3, // paranoid
        };
        lib.defineCMacro("SDL_ASSERT_LEVEL", b.fmt("{d}", .{SDL_ASSERT_LEVEL}));

        lib.linkLibC();

        switch (target.result.os.tag) {
            .windows => {
                lib.addCSourceFiles(.{
                    .root = sdl_dep.path(""),
                    .files = &windows_src_files,
                    .flags = &.{},
                });
                lib.linkSystemLibrary("setupapi");
                lib.linkSystemLibrary("winmm");
                lib.linkSystemLibrary("gdi32");
                lib.linkSystemLibrary("imm32");
                lib.linkSystemLibrary("version");
                lib.linkSystemLibrary("oleaut32");
                lib.linkSystemLibrary("ole32");
                lib.defineCMacro("SDL_USE_BUILTIN_OPENGL_DEFINITIONS", "1");
            },
            .macos => {
                lib.addCSourceFiles(.{
                    .root = sdl_dep.path(""),
                    .files = &darwin_src_files,
                    .flags = &.{},
                });
                lib.addCSourceFiles(.{
                    .root = sdl_dep.path(""),
                    .files = &objective_c_src_files,
                    .flags = &.{"-fobjc-arc"},
                });
                lib.defineCMacro("SDL_USE_BUILTIN_OPENGL_DEFINITIONS", "1");

                // TODO: re-check which frameworks are needed
                lib.linkFramework("AudioToolbox");
                lib.linkFramework("AVFoundation");
                lib.linkFramework("Carbon");
                lib.linkFramework("Cocoa");
                lib.linkFramework("CoreAudio");
                lib.linkFramework("CoreBluetooth");
                lib.linkFramework("CoreGraphics");
                lib.linkFramework("CoreHaptics");
                lib.linkFramework("CoreMotion");
                lib.linkFramework("CoreMedia");
                lib.linkFramework("CoreVideo");
                lib.linkFramework("ForceFeedback");
                lib.linkFramework("Foundation");
                lib.linkFrameworkWeak("GameController");
                lib.linkFramework("IOKit");
                lib.linkFrameworkWeak("Metal");
                lib.linkFrameworkWeak("QuartzCore");
                lib.linkFrameworkWeak("UniformTypeIdentifiers");
                lib.linkSystemLibrary("objc");

                const sdk = std.zig.system.darwin.getSdk(b.allocator, b.host.result) orelse
                    @panic("macOS SDK is missing");
                lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
                lib.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
                lib.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
            },
            else => {
                const values = .{
                    .SDL_DEFAULT_ASSERT_LEVEL_CONFIGURED = 1,

                    .HAVE_GCC_ATOMICS = 1,

                    // to avoid issues in SDL_stdinc.h
                    .HAVE_LIBC = 1,
                    // Useful headers
                    .STDC_HEADERS = 1,
                    .HAVE_ALLOCA_H = 1,
                    .HAVE_CTYPE_H = 1,
                    .HAVE_FLOAT_H = 1,
                    .HAVE_ICONV_H = 1,
                    .HAVE_INTTYPES_H = 1,
                    .HAVE_LIMITS_H = 1,
                    .HAVE_MALLOC_H = 1,
                    .HAVE_MATH_H = 1,
                    .HAVE_MEMORY_H = 1,
                    .HAVE_SIGNAL_H = 1,
                    .HAVE_STDARG_H = 1,
                    .HAVE_STDDEF_H = 1,
                    .HAVE_STDINT_H = 1,
                    .HAVE_STDIO_H = 1,
                    .HAVE_STDLIB_H = 1,
                    .HAVE_STRINGS_H = 1,
                    .HAVE_STRING_H = 1,
                    .HAVE_SYS_TYPES_H = 1,
                    .HAVE_WCHAR_H = 1,

                    // C library functions
                    .HAVE_DLOPEN = 1,
                    .HAVE_MALLOC = 1,
                    .HAVE_CALLOC = 1,
                    .HAVE_REALLOC = 1,
                    .HAVE_FREE = 1,
                    .HAVE_GETENV = 1,
                    .HAVE_SETENV = 1,
                    .HAVE_PUTENV = 1,
                    .HAVE_UNSETENV = 1,
                    .HAVE_ABS = 1,
                    .HAVE_BCOPY = 1,
                    .HAVE_MEMSET = 1,
                    .HAVE_MEMCPY = 1,
                    .HAVE_MEMMOVE = 1,
                    .HAVE_MEMCMP = 1,
                    .HAVE_WCSLEN = 1,
                    .HAVE_WCSNLEN = 1,
                    // /* #undef HAVE_WCSLCPY */
                    // /* #undef HAVE_WCSLCAT */
                    // /* #undef HAVE__WCSDUP */
                    .HAVE_WCSDUP = 1,
                    .HAVE_WCSSTR = 1,
                    .HAVE_WCSCMP = 1,
                    .HAVE_WCSNCMP = 1,
                    .HAVE_WCSCASECMP = 1,
                    // /* #undef HAVE__WCSICMP */
                    .HAVE_WCSNCASECMP = 1,
                    // /* #undef HAVE__WCSNICMP */
                    .HAVE_WCSTOL = 1,
                    .HAVE_STRLEN = 1,
                    .HAVE_STRNLEN = 1,
                    // /* #undef HAVE_STRLCPY */
                    // /* #undef HAVE_STRLCAT */
                    // /* #undef HAVE__STRREV */
                    // /* #undef HAVE__STRUPR */
                    // /* #undef HAVE__STRLWR */
                    .HAVE_INDEX = 1,
                    .HAVE_RINDEX = 1,
                    .HAVE_STRCHR = 1,
                    .HAVE_STRRCHR = 1,
                    .HAVE_STRSTR = 1,
                    // /* #undef HAVE_STRNSTR */
                    .HAVE_STRTOK_R = 1,
                    // /* #undef HAVE_ITOA */
                    // /* #undef HAVE__LTOA */
                    // /* #undef HAVE__UITOA */
                    // /* #undef HAVE__ULTOA */
                    .HAVE_STRTOL = 1,
                    .HAVE_STRTOUL = 1,
                    // /* #undef HAVE__I64TOA */
                    // /* #undef HAVE__UI64TOA */
                    .HAVE_STRTOLL = 1,
                    .HAVE_STRTOULL = 1,
                    .HAVE_STRTOD = 1,
                    .HAVE_ATOI = 1,
                    .HAVE_ATOF = 1,
                    .HAVE_STRCMP = 1,
                    .HAVE_STRNCMP = 1,
                    // /* #undef HAVE__STRICMP */
                    .HAVE_STRCASECMP = 1,
                    // /* #undef HAVE__STRNICMP */
                    .HAVE_STRNCASECMP = 1,
                    .HAVE_STRCASESTR = 1,
                    .HAVE_SSCANF = 1,
                    .HAVE_VSSCANF = 1,
                    .HAVE_VSNPRINTF = 1,
                    .HAVE_ACOS = 1,
                    .HAVE_ACOSF = 1,
                    .HAVE_ASIN = 1,
                    .HAVE_ASINF = 1,
                    .HAVE_ATAN = 1,
                    .HAVE_ATANF = 1,
                    .HAVE_ATAN2 = 1,
                    .HAVE_ATAN2F = 1,
                    .HAVE_CEIL = 1,
                    .HAVE_CEILF = 1,
                    .HAVE_COPYSIGN = 1,
                    .HAVE_COPYSIGNF = 1,
                    .HAVE_COS = 1,
                    .HAVE_COSF = 1,
                    .HAVE_EXP = 1,
                    .HAVE_EXPF = 1,
                    .HAVE_FABS = 1,
                    .HAVE_FABSF = 1,
                    .HAVE_FLOOR = 1,
                    .HAVE_FLOORF = 1,
                    .HAVE_FMOD = 1,
                    .HAVE_FMODF = 1,
                    .HAVE_LOG = 1,
                    .HAVE_LOGF = 1,
                    .HAVE_LOG10 = 1,
                    .HAVE_LOG10F = 1,
                    .HAVE_LROUND = 1,
                    .HAVE_LROUNDF = 1,
                    .HAVE_MODF = 1,
                    .HAVE_MODFF = 1,
                    .HAVE_POW = 1,
                    .HAVE_POWF = 1,
                    .HAVE_ROUND = 1,
                    .HAVE_ROUNDF = 1,
                    .HAVE_SCALBN = 1,
                    .HAVE_SCALBNF = 1,
                    .HAVE_SIN = 1,
                    .HAVE_SINF = 1,
                    .HAVE_SQRT = 1,
                    .HAVE_SQRTF = 1,
                    .HAVE_TAN = 1,
                    .HAVE_TANF = 1,
                    .HAVE_TRUNC = 1,
                    .HAVE_TRUNCF = 1,
                    .HAVE_FOPEN64 = 1,
                    .HAVE_FSEEKO = 1,
                    .HAVE_FSEEKO64 = 1,
                    .HAVE_MEMFD_CREATE = 1,
                    .HAVE_POSIX_FALLOCATE = 1,
                    .HAVE_SIGACTION = 1,
                    .HAVE_SA_SIGACTION = 1,
                    .HAVE_ST_MTIM = 1,
                    .HAVE_SETJMP = 1,
                    .HAVE_NANOSLEEP = 1,
                    .HAVE_GMTIME_R = 1,
                    .HAVE_LOCALTIME_R = 1,
                    .HAVE_NL_LANGINFO = 1,
                    .HAVE_SYSCONF = 1,
                    // /* #undef HAVE_SYSCTLBYNAME */
                    .HAVE_CLOCK_GETTIME = 1,
                    .HAVE_GETPAGESIZE = 1,
                    .HAVE_ICONV = 1,
                    // /* #undef SDL_USE_LIBICONV */
                    .HAVE_PTHREAD_SETNAME_NP = 1,
                    // /* #undef HAVE_PTHREAD_SET_NAME_NP */
                    .HAVE_SEM_TIMEDWAIT = 1,
                    .HAVE_GETAUXVAL = 1,
                    // /* #undef HAVE_ELF_AUX_INFO */
                    .HAVE_POLL = 1,
                    .HAVE__EXIT = 1,

                    .HAVE_DBUS_DBUS_H = 1,
                    .HAVE_FCITX = 1,
                    // /* #undef HAVE_IBUS_IBUS_H */
                    .HAVE_SYS_INOTIFY_H = 1,
                    .HAVE_INOTIFY_INIT = 1,
                    .HAVE_INOTIFY_INIT1 = 1,
                    .HAVE_INOTIFY = 1,
                    // /* #undef HAVE_LIBUSB */
                    .HAVE_O_CLOEXEC = 1,

                    .HAVE_LINUX_INPUT_H = 1,

                    .HAVE_LIBDECOR_H = 1,

                    .SDL_AUDIO_DRIVER_ALSA = 1,
                    .SDL_AUDIO_DRIVER_DISK = 1,
                    .SDL_AUDIO_DRIVER_DUMMY = 1,
                    .SDL_AUDIO_DRIVER_PIPEWIRE = 1,
                    .SDL_AUDIO_DRIVER_PULSEAUDIO = 1,

                    .SDL_INPUT_LINUXEV = 1,
                    .SDL_INPUT_LINUXKD = 1,
                    .SDL_JOYSTICK_LINUX = 1,
                    .SDL_JOYSTICK_HIDAPI = 1,
                    .SDL_JOYSTICK_VIRTUAL = 1,
                    .SDL_HAPTIC_LINUX = 1,

                    .SDL_SENSOR_DUMMY = 1,

                    .SDL_LOADSO_DLOPEN = 1,

                    .SDL_THREAD_PTHREAD = 1,
                    .SDL_THREAD_PTHREAD_RECURSIVE_MUTEX = 1,
                    // .SDL_THREAD_PTHREAD_RECURSIVE_MUTEX_NP = 1,

                    .SDL_TIME_UNIX = 1,

                    .SDL_TIMER_UNIX = 1,

                    .SDL_VIDEO_DRIVER_DUMMY = 1,
                    .SDL_VIDEO_DRIVER_OFFSCREEN = 1,
                    .SDL_VIDEO_DRIVER_WAYLAND = 1,

                    .SDL_VIDEO_RENDER_VULKAN = 1,
                    .SDL_VIDEO_RENDER_OGL = 1,
                    .SDL_VIDEO_RENDER_OGL_ES2 = 1,

                    .SDL_VIDEO_OPENGL = 1,
                    .SDL_VIDEO_OPENGL_ES = 1,
                    .SDL_VIDEO_OPENGL_ES2 = 1,
                    .SDL_VIDEO_OPENGL_GLX = 1,
                    .SDL_VIDEO_OPENGL_EGL = 1,

                    .SDL_VIDEO_VULKAN = 1,

                    .SDL_POWER_LINUX = 1,

                    .SDL_FILESYSTEM_UNIX = 1,

                    .SDL_STORAGE_GENERIC = 1,
                    .SDL_STORAGE_STEAM = 1,

                    .SDL_FSOPS_POSIX = 1,

                    // sudo apt-get install v4l-utils
                    // sudo modprobe v4l2loopback
                    // v4l2-ctl --list-devices
                    .SDL_CAMERA_DRIVER_DUMMY = 1,
                    .SDL_CAMERA_DRIVER_V4L2 = 1,

                    // #define DYNAPI_NEEDS_DLOPEN 1

                    .SDL_USE_IME = 1,

                    .SDL_LIBDECOR_VERSION_MAJOR = 0,
                    .SDL_LIBDECOR_VERSION_MINOR = 1,
                    .SDL_LIBDECOR_VERSION_PATCH = 0,

                    // ?
                    .SDL_DISABLE_LSX = 1,
                    .SDL_DISABLE_LASX = 1,
                    .SDL_DISABLE_NEON = 1,
                };
                lib.installConfigHeader(b.addConfigHeader(.{
                    .style = .{ .cmake = sdl_dep.path(
                        "include/build_config/SDL_build_config.h.cmake",
                    ) },
                    .include_path = "include/build_config/SDL_build_config.h",
                }, values));

                lib.addCSourceFiles(.{
                    .root = sdl_dep.path(""),
                    .files = &linux_src_files,
                    .flags = &.{},
                });

                // TODO: fix -Wno-incompatible-pointer-types issue with SDL_PIPEWIRE_SHARED=OFF
                lib.addCSourceFiles(.{
                    .root = sdl_dep.path(""),
                    .files = &.{"src/audio/pipewire/SDL_pipewire.c"},
                    .flags = &.{"-Wno-incompatible-pointer-types"},
                });

                inline for (std.meta.fields(@TypeOf(values))) |f| {
                    const value = b.fmt("{any}", .{@field(values, f.name)});
                    lib.defineCMacro(f.name, value);
                }

                // SDL3_DYNAMIC_API=/my/actual/libSDL3.so.0
                //
                // If we want to _avoid_ dyn api, we can do so:
                // lib.defineCMacro("SDL_dynapi_h_", "1");
                // lib.defineCMacro("SDL_DYNAMIC_API", "0");

                // Avoid
                // SDL/include/build_config/SDL_build_config_minimal.h
                lib.defineCMacro("SDL_build_config_minimal_h_", "1");

                //--

                lib.linkSystemLibrary("dbus-1");

                const wayland_scanner = wayland_dep.artifact("wayland-scanner");
                {
                    const wayland_xmls = [_][]const u8{
                        "alpha-modifier-v1",
                        "cursor-shape-v1",
                        "fractional-scale-v1",
                        "frog-color-management-v1",
                        "idle-inhibit-unstable-v1",
                        "input-timestamps-unstable-v1",
                        "kde-output-order-v1",
                        "keyboard-shortcuts-inhibit-unstable-v1",
                        "pointer-constraints-unstable-v1",
                        "primary-selection-unstable-v1",
                        "relative-pointer-unstable-v1",
                        "tablet-v2",
                        "text-input-unstable-v3",
                        "viewporter",
                        "wayland",
                        "xdg-activation-v1",
                        "xdg-decoration-unstable-v1",
                        "xdg-dialog-v1",
                        "xdg-foreign-unstable-v2",
                        "xdg-output-unstable-v1",
                        "xdg-shell",
                        "xdg-toplevel-icon-v1",
                    };
                    const copy_headers = b.addWriteFiles();
                    for (wayland_xmls) |file| {
                        const generate_header = b.addRunArtifact(wayland_scanner);
                        generate_header.addArg("client-header");
                        generate_header.addFileArg(sdl_dep.path(b.fmt("wayland-protocols/{s}.xml", .{file})));
                        const header_filename = b.fmt("{s}-client-protocol.h", .{file});
                        const header = generate_header.addOutputFileArg(header_filename);

                        const generate_source = b.addRunArtifact(wayland_scanner);
                        generate_source.addArg("private-code");
                        generate_source.addFileArg(sdl_dep.path(b.fmt("wayland-protocols/{s}.xml", .{file})));
                        const source = generate_source.addOutputFileArg(b.fmt("{s}-protocol.c", .{file}));

                        _ = copy_headers.addCopyFile(header, header_filename);
                        lib.addCSourceFile(.{ .file = source, .flags = &.{} });
                    }
                    lib.addIncludePath(copy_headers.getDirectory());
                }

                // TODO: build wayland from source?
                //
                //   sudo apt install -y libwayland-dev
                //
                // TODO: It compiles, but we get errors like this:
                //
                //   libwayland-client.so' is neither ET_REL nor LLVM bitcode
                //
                // lib.linkLibrary(wayland_dep.artifact("wayland-client"));
                // lib.linkLibrary(wayland_dep.artifact("wayland-egl"));
                // lib.linkLibrary(wayland_dep.artifact("wayland-cursor"));
                lib.linkSystemLibrary("wayland-client");
                lib.linkSystemLibrary("wayland-egl");
                lib.linkSystemLibrary("wayland-cursor");

                // NOTE: We can build from source, but it's involved,
                // and will require building yacc/bison...
                //
                // https://github.com/xkbcommon/libxkbcommon
                lib.linkSystemLibrary("xkbcommon");

                // https://www.mesa3d.org/
                //
                //   sudo apt install -y libegl1-mesa-dev
                //
                lib.linkSystemLibrary("EGL");
                lib.linkSystemLibrary("GLESv2");

                // sudo apt install libdecor-0-dev
                //
                // TODO: why isn't `linkSystemLibrary` enough to find the headers?
                // See https://github.com/ziglang/zig/issues/18465
                lib.linkSystemLibrary("decor-0");
                lib.addIncludePath(.{ .cwd_relative = "/usr/include/libdecor-0" });

                //-- SDL_AUDIODRIVER

                // SDL_AUDIO_DRIVER=pipewire
                // sudo apt install libpipewire-0.3-dev
                //
                // https://wiki.archlinux.org/title/PipeWire
                //
                // TODO: why isn't `linkSystemLibrary` enough to find the headers?
                // See https://github.com/ziglang/zig/issues/18465
                lib.linkSystemLibrary("pipewire-0.3");
                lib.addIncludePath(.{ .cwd_relative = "/usr/include/pipewire-0.3" });
                lib.addIncludePath(.{ .cwd_relative = "/usr/include/spa-0.2" });

                // SDL_AUDIO_DRIVER=pulseaudio
                // sudo apt install -y libpulse-dev
                lib.linkSystemLibrary("pulse");

                // SDL_AUDIO_DRIVER=alsa
                // sudo apt install -y libasound2-dev
                lib.linkSystemLibrary("asound");
            },
        }
        lib.installHeadersDirectory(sdl_dep.path("include/SDL3"), "SDL3", .{});
        b.installArtifact(lib);
    }

    // needed to allow SDL_ttf to #include "SDL.h"
    const sdl_for_libs = b.addStaticLibrary(.{
        .name = "SDL3-for-libs",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.addWriteFiles().add("stub.c", ""),
    });
    {
        sdl_for_libs.addIncludePath(sdl_dep.path("include"));
        sdl_for_libs.installHeadersDirectory(sdl_dep.path("include"), "", .{});
        b.installArtifact(sdl_for_libs);
    }

    const SDL_ttf = b.addStaticLibrary(.{
        .name = "SDL3_ttf",
        .target = target,
        .optimize = optimize,
    });
    {
        SDL_ttf.addCSourceFiles(.{
            .root = sdl_ttf_dep.path(""),
            .files = &.{"src/SDL_ttf.c"},
            .flags = &.{},
        });
        SDL_ttf.addIncludePath(sdl_ttf_dep.path("include"));
        SDL_ttf.installHeadersDirectory(sdl_ttf_dep.path("include/SDL3_ttf"), "SDL3_ttf", .{});

        SDL_ttf.linkLibrary(freetype_dep.artifact("freetype"));

        if (target.result.os.tag == .macos) {
            const sdk = std.zig.system.darwin.getSdk(b.allocator, b.host.result) orelse
                @panic("macOS SDK is missing");
            SDL_ttf.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
            SDL_ttf.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
            SDL_ttf.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
        }

        SDL_ttf.linkLibrary(sdl_for_libs);

        b.installArtifact(SDL_ttf);
    }

    //--

    const module = b.addModule("sdl", .{
        .root_source_file = b.addWriteFiles().add("src/lib.zig",
            \\pub const c = @cImport({
            \\    @cInclude("SDL3/SDL.h");
            \\    @cInclude("SDL3_ttf/SDL_ttf.h");
            \\});
        ),
        .link_libc = true,
    });
    {
        module.linkLibrary(lib);
        module.linkLibrary(SDL_ttf);

        // In case you need to build it the non-zig way, for comparison:
        //
        // ```
        // rm -rf build && mkdir build && cd build
        // cmake -DSDL_TEST=ON -DSDL_TESTS=ON ..
        // cmake --build .
        // cmake --install . --prefix install
        // ```
        // module.linkSystemLibrary("SDL3", .{ .needed = true });
        // module.addLibraryPath(.{ .cwd_relative = "SDL/build/install/lib");
        // module.addIncludePath(b.path("SDL/build/install/include"));
    }

    const zig_examples = [_][]const u8{
        "minimal",
        "ttf",
    };
    for (zig_examples) |name| {
        const exe = b.addExecutable(.{
            .name = b.fmt("zig-{s}", .{name}),
            .target = target,
            .root_source_file = b.path(b.fmt("src/{s}.zig", .{name})),
            .optimize = optimize,
        });
        exe.root_module.addImport("sdl", module);

        if (target.result.os.tag == .macos) {
            const sdk = std.zig.system.darwin.getSdk(b.allocator, b.host.result) orelse
                @panic("macOS SDK is missing");
            exe.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
            exe.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
            exe.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
        }

        const run = b.addRunArtifact(exe);

        if (b.args) |args| run.addArgs(args);

        // TODO: provide general-purpose fonts?
        if (std.mem.eql(u8, name, "ttf")) {
            const font_dep = b.dependency("fonts", .{});
            exe.root_module.addImport("fonts", font_dep.module("fonts"));
        }

        const install = b.addInstallBinFile(exe.getEmittedBin(), name);

        const run_step = b.step(b.fmt("zig-{s}", .{name}), b.fmt("Run src/{s}.zig", .{name}));
        run_step.dependOn(&run.step);
        run_step.dependOn(&install.step); // install example if you run it
    }

    //--

    const test_step = b.step("test", "Build all test programs");

    const test_utils = b.addStaticLibrary(.{
        .name = "testutils",
        .target = target,
        .optimize = optimize,
    });
    {
        test_utils.addIncludePath(sdl_dep.path("src"));
        test_utils.addIncludePath(sdl_dep.path("include"));
        test_utils.addIncludePath(sdl_dep.path("include/build_config"));
        // test_utils.addIncludePath(sdl_dep.path("include/SDL3"));

        test_utils.addCSourceFiles(.{
            .root = sdl_dep.path(""),
            .files = &.{
                "test/testutils.c",

                "src/test/SDL_test_assert.c",
                "src/test/SDL_test_common.c",
                "src/test/SDL_test_compare.c",
                "src/test/SDL_test_crc32.c",
                "src/test/SDL_test_font.c",
                "src/test/SDL_test_fuzzer.c",
                "src/test/SDL_test_harness.c",
                "src/test/SDL_test_log.c",
                "src/test/SDL_test_md5.c",
                "src/test/SDL_test_memory.c",

                "test/gamepadutils.c",

                "test/testautomation_audio.c",
                "test/testautomation_clipboard.c",
                "test/testautomation_events.c",
                "test/testautomation_guid.c",
                "test/testautomation_hints.c",
                "test/testautomation_images.c",
                // TODO: fix issue here, then re-enable
                // "test/testautomation_intrinsics.c",
                "test/testautomation_iostream.c",
                "test/testautomation_joystick.c",
                "test/testautomation_keyboard.c",
                "test/testautomation_log.c",
                "test/testautomation_main.c",
                "test/testautomation_math.c",
                "test/testautomation_mouse.c",
                "test/testautomation_pixels.c",
                "test/testautomation_platform.c",
                "test/testautomation_properties.c",
                "test/testautomation_rect.c",
                "test/testautomation_render.c",
                "test/testautomation_sdltest.c",
                "test/testautomation_stdlib.c",
                "test/testautomation_subsystems.c",
                "test/testautomation_surface.c",
                "test/testautomation_time.c",
                "test/testautomation_timer.c",
                "test/testautomation_video.c",
            },
            .flags = &.{},
        });
        test_utils.installHeader(sdl_dep.path("test/testutils.h"), "testutils.h");
        test_utils.linkLibC();
    }

    const tests = [_][]const u8{
        "checkkeys",
        "checkkeysthreads",
        "loopwave",
        "pretest",
        "testatomic",
        "testaudio",
        "testaudiorecording",
        "testaudiohotplug",
        "testaudioinfo",
        "testaudiostreamdynamicresample",
        "testautomation",
        "testbounds",
        "testcamera",
        "testcolorspace",
        "testcontroller",
        "testcustomcursor",
        "testdialog",
        "testdisplayinfo",
        "testdraw",
        "testdrawchessboard",
        "testdropfile",
        "testerror",
        "testevdev",
        "testffmpeg",
        "testffmpeg_vulkan",
        "testfile",
        "testfilesystem",
        "testgeometry",
        "testgl",
        "testgles",
        "testgles2",
        "testgles2_sdf",
        "testhaptic",
        "testhittesting",
        "testhotplug",
        "testiconv",
        "testime",
        "testintersections",
        "testkeys",
        "testloadso",
        "testlocale",
        "testlock",
        "testmanymouse",
        "testmessage",
        "testmodal",
        "testmouse",
        "testmultiaudio",
        "testnative",
        "testnativew32",
        "testnativewayland",
        "testnativex11",
        "testoffscreen",
        "testoverlay",
        "testpen",
        "testplatform",
        "testpopup",
        "testpower",
        "testqsort",
        "testrelative",
        "testrendercopyex",
        "testrendertarget",
        "testresample",
        "testrumble",
        "testrwlock",
        "testscale",
        "testsem",
        "testsensor",
        "testshader",
        "testshape",
        "testsprite",
        "testspriteminimal",
        "teststreaming",
        "testsurround",
        "testthread",
        "testtime",
        "testtimer",
        "testurl",
        "testver",
        "testviewport",
        "testvulkan",
        "testwaylandcustom",
        "testwm",
        "testyuv",
        "testyuv_cvt",
        "torturethread",
    };
    for (tests) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFile(.{
            .file = sdl_dep.path(b.fmt("test/{s}.c", .{name})),
            .flags = &.{},
        });
        exe.linkLibrary(lib);
        exe.linkLibrary(test_utils);

        if (target.result.os.tag == .macos) {
            const sdk = std.zig.system.darwin.getSdk(b.allocator, b.host.result) orelse
                @panic("macOS SDK is missing");
            exe.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
            exe.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
            exe.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
        }

        const run = b.addRunArtifact(exe);

        run.setCwd(sdl_dep.path("test"));
        if (b.args) |args| run.addArgs(args);
        // if (std.mem.eql(u8, name, "testaudio")) {
        //     run.addArgs(&.{ "--log", "all" });
        // }

        const install = b.addInstallBinFile(exe.getEmittedBin(), name);
        test_step.dependOn(&install.step);

        const run_step = b.step(name, b.fmt("Run {s}", .{name}));
        run_step.dependOn(&run.step);
        run_step.dependOn(&install.step); // install test if you run it
    }

    {
        const SdlExample = struct {
            path: []const u8,
            name: []const u8,
        };

        const sdl_examples = [_]SdlExample{
            SdlExample{ .path = "examples/audio/01-simple-playback", .name = "simple-playback" },
            SdlExample{ .path = "examples/audio/02-simple-playback-callback", .name = "simple-playback-callback" },
            SdlExample{ .path = "examples/audio/03-load-wav", .name = "load-wav" },
            SdlExample{ .path = "examples/camera/01-read-and-draw", .name = "read-and-draw" },
            SdlExample{ .path = "examples/game/01-snake", .name = "snake" },
            SdlExample{ .path = "examples/pen/01-drawing-lines", .name = "drawing-lines" },
            SdlExample{ .path = "examples/renderer/01-clear", .name = "renderer-clear" },
            SdlExample{ .path = "examples/renderer/02-primitives", .name = "renderer-primitives" },
        };

        for (sdl_examples) |sdl_example| {
            const path = sdl_example.path;
            const name = sdl_example.name;

            const exe = b.addExecutable(.{
                .name = b.fmt("example-{s}", .{name}),
                .target = target,
                .optimize = optimize,
            });
            exe.addCSourceFile(.{
                .file = sdl_dep.path(b.fmt("{s}/{s}.c", .{ path, name })),
                .flags = &.{},
            });
            exe.linkLibrary(lib);

            if (target.result.os.tag == .macos) {
                const sdk = std.zig.system.darwin.getSdk(b.allocator, b.host.result) orelse
                    @panic("macOS SDK is missing");
                exe.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
                exe.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
                exe.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
            }

            const run = b.addRunArtifact(exe);

            if (b.args) |args| run.addArgs(args);

            if (std.mem.eql(u8, name, "load-wav")) {
                run.setCwd(sdl_dep.path("test"));
            }

            const install = b.addInstallBinFile(exe.getEmittedBin(), name);
            test_step.dependOn(&install.step);

            const run_step = b.step(b.fmt("example-{s}", .{name}), b.fmt("Run {s}", .{name}));
            run_step.dependOn(&run.step);
            run_step.dependOn(&install.step); // install example if you run it
        }
    }
}

const generic_src_files = [_][]const u8{
    "src/SDL.c",
    "src/SDL_assert.c",
    "src/SDL_error.c",
    "src/SDL_guid.c",
    "src/SDL_hashtable.c",
    "src/SDL_hints.c",
    "src/SDL_list.c",
    "src/SDL_log.c",
    "src/SDL_properties.c",
    "src/SDL_utils.c",

    "src/atomic/SDL_atomic.c",
    "src/atomic/SDL_spinlock.c",

    "src/audio/SDL_audio.c",
    "src/audio/SDL_audiocvt.c",
    "src/audio/SDL_audiodev.c",
    "src/audio/SDL_audioqueue.c",
    "src/audio/SDL_audioresample.c",
    "src/audio/SDL_audiotypecvt.c",
    "src/audio/SDL_mixer.c",
    "src/audio/SDL_wave.c",
    "src/audio/dummy/SDL_dummyaudio.c",

    "src/camera/SDL_camera.c",
    "src/camera/dummy/SDL_camera_dummy.c",

    "src/core/SDL_core_unsupported.c",
    "src/main/SDL_runapp.c",

    "src/cpuinfo/SDL_cpuinfo.c",

    // "src/dialog/dummy/SDL_dummydialog.c",
    "src/dialog/SDL_dialog_utils.c",

    "src/dynapi/SDL_dynapi.c",

    "src/events/imKStoUCS.c",
    "src/events/SDL_categories.c",
    "src/events/SDL_clipboardevents.c",
    "src/events/SDL_displayevents.c",
    "src/events/SDL_dropevents.c",
    "src/events/SDL_events.c",
    "src/events/SDL_keyboard.c",
    "src/events/SDL_keymap.c",
    "src/events/SDL_keysym_to_scancode.c",
    "src/events/SDL_mouse.c",
    "src/events/SDL_pen.c",
    "src/events/SDL_quit.c",
    "src/events/SDL_scancode_tables.c",
    "src/events/SDL_touch.c",
    "src/events/SDL_windowevents.c",

    "src/file/SDL_iostream.c",

    "src/filesystem/SDL_filesystem.c",
    // "src/filesystem/dummy/SDL_sysfilesystem.c",
    // "src/filesystem/dummy/SDL_sysfsops.c",

    "src/gpu/SDL_gpu.c",
    // "src/gpu/d3d11/SDL_gpu_d3d11.c",
    // "src/gpu/d3d12/SDL_gpu_d3d12.c",
    "src/gpu/vulkan/SDL_gpu_vulkan.c",

    "src/haptic/SDL_haptic.c",
    "src/haptic/dummy/SDL_syshaptic.c",

    "src/hidapi/SDL_hidapi.c",

    "src/joystick/SDL_gamepad.c",
    "src/joystick/SDL_joystick.c",
    "src/joystick/SDL_steam_virtual_gamepad.c",
    // "src/joystick/dummy/SDL_sysjoystick.c",
    "src/joystick/controller_type.c",
    "src/joystick/virtual/SDL_virtualjoystick.c",

    "src/libm/e_atan2.c",
    "src/libm/e_exp.c",
    "src/libm/e_fmod.c",
    "src/libm/e_log10.c",
    "src/libm/e_log.c",
    "src/libm/e_pow.c",
    "src/libm/e_rem_pio2.c",
    "src/libm/e_sqrt.c",
    "src/libm/k_cos.c",
    "src/libm/k_rem_pio2.c",
    "src/libm/k_sin.c",
    "src/libm/k_tan.c",
    "src/libm/s_atan.c",
    "src/libm/s_copysign.c",
    "src/libm/s_cos.c",
    "src/libm/s_fabs.c",
    "src/libm/s_floor.c",
    "src/libm/s_isinf.c",
    "src/libm/s_isinff.c",
    "src/libm/s_isnan.c",
    "src/libm/s_isnanf.c",
    "src/libm/s_modf.c",
    "src/libm/s_scalbn.c",
    "src/libm/s_sin.c",
    "src/libm/s_tan.c",

    "src/loadso/dlopen/SDL_sysloadso.c",
    // "src/loadso/dummy/SDL_sysloadso.c",

    "src/locale/SDL_locale.c",
    // "src/locale/dummy/SDL_syslocale.c",

    "src/main/SDL_main_callbacks.c",
    // "src/main/emscripten/SDL_sysmain_callbacks.c",
    "src/main/generic/SDL_sysmain_callbacks.c",

    "src/misc/SDL_url.c",
    // "src/misc/dummy/SDL_sysurl.c",

    "src/power/SDL_power.c",

    "src/render/SDL_d3dmath.c",
    "src/render/SDL_render.c",
    "src/render/SDL_render_unsupported.c",
    "src/render/SDL_yuv_sw.c",
    "src/render/direct3d/SDL_render_d3d.c",
    "src/render/direct3d/SDL_shaders_d3d.c",
    "src/render/direct3d11/SDL_render_d3d11.c",
    "src/render/direct3d11/SDL_shaders_d3d11.c",
    "src/render/direct3d12/SDL_render_d3d12.c",
    "src/render/direct3d12/SDL_shaders_d3d12.c",
    "src/render/opengl/SDL_render_gl.c",
    "src/render/opengl/SDL_shaders_gl.c",
    "src/render/opengles2/SDL_render_gles2.c",
    "src/render/opengles2/SDL_shaders_gles2.c",
    "src/render/ps2/SDL_render_ps2.c",
    "src/render/psp/SDL_render_psp.c",
    "src/render/software/SDL_blendfillrect.c",
    "src/render/software/SDL_blendline.c",
    "src/render/software/SDL_blendpoint.c",
    "src/render/software/SDL_drawline.c",
    "src/render/software/SDL_drawpoint.c",
    "src/render/software/SDL_render_sw.c",
    "src/render/software/SDL_rotate.c",
    "src/render/software/SDL_triangle.c",

    "src/render/vitagxm/SDL_render_vita_gxm.c",
    "src/render/vitagxm/SDL_render_vita_gxm_memory.c",
    "src/render/vitagxm/SDL_render_vita_gxm_tools.c",
    "src/render/vulkan/SDL_render_vulkan.c",
    "src/render/vulkan/SDL_shaders_vulkan.c",

    "src/sensor/SDL_sensor.c",
    "src/sensor/dummy/SDL_dummysensor.c",

    "src/stdlib/SDL_crc16.c",
    "src/stdlib/SDL_crc32.c",
    "src/stdlib/SDL_getenv.c",
    "src/stdlib/SDL_iconv.c",
    "src/stdlib/SDL_malloc.c",
    "src/stdlib/SDL_memcpy.c",
    "src/stdlib/SDL_memmove.c",
    "src/stdlib/SDL_memset.c",
    "src/stdlib/SDL_mslibc.c",
    "src/stdlib/SDL_qsort.c",
    "src/stdlib/SDL_random.c",
    "src/stdlib/SDL_stdlib.c",
    "src/stdlib/SDL_string.c",
    "src/stdlib/SDL_strtokr.c",

    "src/storage/SDL_storage.c",
    "src/storage/generic/SDL_genericstorage.c",
    "src/storage/steam/SDL_steamstorage.c",

    "src/thread/SDL_thread.c",
    // "src/thread/generic/SDL_syscond.c",
    // "src/thread/generic/SDL_sysmutex.c",
    // "src/thread/generic/SDL_sysrwlock.c",
    // "src/thread/generic/SDL_syssem.c",
    // breaks testcamera
    //   DEBUG: Threads are not supported on this platform
    //   DEBUG: Couldn't create camera thread
    // "src/thread/generic/SDL_systhread.c",
    // "src/thread/generic/SDL_systls.c",

    "src/time/SDL_time.c",
    "src/timer/SDL_timer.c",

    "src/video/SDL_RLEaccel.c",
    "src/video/SDL_blit.c",
    "src/video/SDL_blit_0.c",
    "src/video/SDL_blit_1.c",
    "src/video/SDL_blit_A.c",
    "src/video/SDL_blit_N.c",
    "src/video/SDL_blit_auto.c",
    "src/video/SDL_blit_copy.c",
    "src/video/SDL_blit_slow.c",
    "src/video/SDL_bmp.c",
    "src/video/SDL_clipboard.c",
    "src/video/SDL_egl.c",
    "src/video/SDL_fillrect.c",
    "src/video/SDL_pixels.c",
    "src/video/SDL_rect.c",
    "src/video/SDL_stretch.c",
    "src/video/SDL_surface.c",
    "src/video/SDL_video.c",
    "src/video/SDL_video_unsupported.c",
    "src/video/SDL_vulkan_utils.c",
    "src/video/SDL_yuv.c",
    "src/video/dummy/SDL_nullevents.c",
    "src/video/dummy/SDL_nullframebuffer.c",
    "src/video/dummy/SDL_nullvideo.c",
    "src/video/offscreen/SDL_offscreenvulkan.c",
    "src/video/yuv2rgb/yuv_rgb_lsx.c",
    "src/video/yuv2rgb/yuv_rgb_sse.c",
    "src/video/yuv2rgb/yuv_rgb_std.c",
};

const linux_src_files = [_][]const u8{
    // "src/audio/aaudio/SDL_aaudio.c",
    "src/audio/alsa/SDL_alsa_audio.c",
    // "src/audio/android/SDL_androidaudio.c",
    // "src/audio/directsound/SDL_directsound.c",
    "src/audio/disk/SDL_diskaudio.c",
    // "src/audio/dsp/SDL_dspaudio.c",
    // "src/audio/emscripten/SDL_emscriptenaudio.c",
    // "src/audio/jack/SDL_jackaudio.c",
    // "src/audio/n3ds/SDL_n3dsaudio.c",
    // "src/audio/netbsd/SDL_netbsdaudio.c",
    // "src/audio/openslES/SDL_openslES.c",

    // TODO: fix -Wno-incompatible-pointer-types issue with SDL_PIPEWIRE_SHARED=OFF
    // "src/audio/pipewire/SDL_pipewire.c",
    "src/camera/pipewire/SDL_camera_pipewire.c",

    // "src/audio/ps2/SDL_ps2audio.c",
    // "src/audio/psp/SDL_pspaudio.c",
    "src/audio/pulseaudio/SDL_pulseaudio.c",
    // "src/audio/qnx/SDL_qsa_audio.c",
    // "src/audio/sndio/SDL_sndioaudio.c",
    // "src/audio/vita/SDL_vitaaudio.c",
    // "src/audio/wasapi/SDL_wasapi.c",
    // "src/audio/wasapi/SDL_wasapi_win32.c",

    // "src/camera/android/SDL_camera_android.c",
    // "src/camera/emscripten/SDL_camera_emscripten.c",
    // "src/camera/mediafoundation/SDL_camera_mediafoundation.c",
    "src/camera/v4l2/SDL_camera_v4l2.c",

    // "src/core/android/SDL_android.c",
    // "src/core/freebsd/SDL_evdev_kbd_freebsd.c",

    "src/core/linux/SDL_dbus.c",

    "src/core/linux/SDL_evdev.c",
    "src/core/linux/SDL_evdev_capabilities.c",
    "src/core/linux/SDL_evdev_kbd.c",
    "src/core/linux/SDL_fcitx.c",
    "src/core/linux/SDL_ibus.c",
    "src/core/linux/SDL_ime.c",
    "src/core/linux/SDL_sandbox.c",
    "src/core/linux/SDL_system_theme.c",
    "src/core/linux/SDL_threadprio.c",
    // "src/core/linux/SDL_udev.c",

    // "src/core/n3ds/SDL_n3ds.c",
    // "src/core/openbsd/SDL_wscons_kbd.c",
    // "src/core/openbsd/SDL_wscons_mouse.c",
    // "src/core/ps2/SDL_ps2.c",
    // "src/core/psp/SDL_psp.c",
    "src/core/unix/SDL_appid.c",
    "src/core/unix/SDL_poll.c",

    "src/dialog/unix/SDL_portaldialog.c",
    "src/dialog/unix/SDL_unixdialog.c",
    "src/dialog/unix/SDL_zenitydialog.c",

    // "src/dialog/android/SDL_androiddialog.c",

    // "src/file/n3ds/SDL_iostreamromfs.c",

    // "src/filesystem/android/SDL_sysfilesystem.c",
    // "src/filesystem/emscripten/SDL_sysfilesystem.c",
    // "src/filesystem/n3ds/SDL_sysfilesystem.c",
    "src/filesystem/posix/SDL_sysfsops.c",
    // "src/filesystem/ps2/SDL_sysfilesystem.c",
    // "src/filesystem/psp/SDL_sysfilesystem.c",
    // "src/filesystem/riscos/SDL_sysfilesystem.c",
    "src/filesystem/unix/SDL_sysfilesystem.c",
    // "src/filesystem/vita/SDL_sysfilesystem.c",

    // "src/haptic/android/SDL_syshaptic.c",
    "src/haptic/linux/SDL_syshaptic.c",

    // "src/hidapi/libusb/hid.c",
    // "src/hidapi/linux/hid.c",
    // "src/hidapi/netbsd/hid.c",

    // "src/joystick/android/SDL_sysjoystick.c",
    // "src/joystick/bsd/SDL_bsdjoystick.c",
    // "src/joystick/emscripten/SDL_sysjoystick.c",
    // "src/joystick/gdk/SDL_gameinputjoystick.c",

    // TODO: generic
    "src/joystick/hidapi/SDL_hidapi_combined.c",
    "src/joystick/hidapi/SDL_hidapi_gamecube.c",
    "src/joystick/hidapi/SDL_hidapi_luna.c",
    "src/joystick/hidapi/SDL_hidapi_ps3.c",
    "src/joystick/hidapi/SDL_hidapi_ps4.c",
    "src/joystick/hidapi/SDL_hidapi_ps5.c",
    "src/joystick/hidapi/SDL_hidapi_rumble.c",
    "src/joystick/hidapi/SDL_hidapi_shield.c",
    "src/joystick/hidapi/SDL_hidapi_stadia.c",
    "src/joystick/hidapi/SDL_hidapi_steam.c",
    "src/joystick/hidapi/SDL_hidapi_steamdeck.c",
    "src/joystick/hidapi/SDL_hidapi_switch.c",
    "src/joystick/hidapi/SDL_hidapi_wii.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360w.c",
    "src/joystick/hidapi/SDL_hidapi_xboxone.c",
    "src/joystick/hidapi/SDL_hidapijoystick.c",
    "src/joystick/linux/SDL_sysjoystick.c",

    // "src/joystick/n3ds/SDL_sysjoystick.c",
    // "src/joystick/ps2/SDL_sysjoystick.c",
    // "src/joystick/psp/SDL_sysjoystick.c",
    "src/joystick/steam/SDL_steamcontroller.c",
    // "src/joystick/vita/SDL_sysjoystick.c",

    // "src/locale/android/SDL_syslocale.c",
    // "src/locale/emscripten/SDL_syslocale.c",
    // "src/locale/n3ds/SDL_syslocale.c",
    "src/locale/unix/SDL_syslocale.c",
    // "src/locale/vita/SDL_syslocale.c",

    // "src/misc/android/SDL_sysurl.c",
    // "src/misc/emscripten/SDL_sysurl.c",
    // "src/misc/riscos/SDL_sysurl.c",
    "src/misc/unix/SDL_sysurl.c",
    // "src/misc/vita/SDL_sysurl.c",

    // "src/power/android/SDL_syspower.c",
    // "src/power/emscripten/SDL_syspower.c",
    // "src/power/haiku/SDL_syspower.c",
    "src/power/linux/SDL_syspower.c",
    // "src/power/n3ds/SDL_syspower.c",
    // "src/power/psp/SDL_syspower.c",
    // "src/power/vita/SDL_syspower.c",

    // "src/sensor/android/SDL_androidsensor.c",
    // "src/sensor/n3ds/SDL_n3dssensor.c",
    // "src/sensor/vita/SDL_vitasensor.c",

    // "src/thread/n3ds/SDL_syscond.c",
    // "src/thread/n3ds/SDL_sysmutex.c",
    // "src/thread/n3ds/SDL_syssem.c",
    // "src/thread/n3ds/SDL_systhread.c",
    // "src/thread/ps2/SDL_syssem.c",
    // "src/thread/ps2/SDL_systhread.c",
    // "src/thread/psp/SDL_sysmutex.c",
    // "src/thread/psp/SDL_syssem.c",
    // "src/thread/psp/SDL_systhread.c",
    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_sysrwlock.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",
    // "src/thread/vita/SDL_sysmutex.c",
    // "src/thread/vita/SDL_syssem.c",
    // "src/thread/vita/SDL_systhread.c",

    // "src/time/n3ds/SDL_systime.c",
    // "src/time/ps2/SDL_systime.c",
    // "src/time/psp/SDL_systime.c",
    "src/time/unix/SDL_systime.c",
    // "src/time/vita/SDL_systime.c",

    // "src/timer/haiku/SDL_systimer.c",
    // "src/timer/n3ds/SDL_systimer.c",
    // "src/timer/ps2/SDL_systimer.c",
    // "src/timer/psp/SDL_systimer.c",
    "src/timer/unix/SDL_systimer.c",
    // "src/timer/vita/SDL_systimer.c",

    // "src/video/android/SDL_androidclipboard.c",
    // "src/video/android/SDL_androidevents.c",
    // "src/video/android/SDL_androidgl.c",
    // "src/video/android/SDL_androidkeyboard.c",
    // "src/video/android/SDL_androidmessagebox.c",
    // "src/video/android/SDL_androidmouse.c",
    // "src/video/android/SDL_androidtouch.c",
    // "src/video/android/SDL_androidvideo.c",
    // "src/video/android/SDL_androidvulkan.c",
    // "src/video/android/SDL_androidwindow.c",
    // "src/video/emscripten/SDL_emscriptenevents.c",
    // "src/video/emscripten/SDL_emscriptenframebuffer.c",
    // "src/video/emscripten/SDL_emscriptenmouse.c",
    // "src/video/emscripten/SDL_emscriptenopengles.c",
    // "src/video/emscripten/SDL_emscriptenvideo.c",
    // "src/video/kmsdrm/SDL_kmsdrmdyn.c",
    // "src/video/kmsdrm/SDL_kmsdrmevents.c",
    // "src/video/kmsdrm/SDL_kmsdrmmouse.c",
    // "src/video/kmsdrm/SDL_kmsdrmopengles.c",
    // "src/video/kmsdrm/SDL_kmsdrmvideo.c",
    // "src/video/kmsdrm/SDL_kmsdrmvulkan.c",
    // "src/video/n3ds/SDL_n3dsevents.c",
    // "src/video/n3ds/SDL_n3dsframebuffer.c",
    // "src/video/n3ds/SDL_n3dsswkb.c",
    // "src/video/n3ds/SDL_n3dstouch.c",
    // "src/video/n3ds/SDL_n3dsvideo.c",
    "src/video/offscreen/SDL_offscreenevents.c",
    "src/video/offscreen/SDL_offscreenframebuffer.c",
    "src/video/offscreen/SDL_offscreenopengles.c",
    "src/video/offscreen/SDL_offscreenvideo.c",
    "src/video/offscreen/SDL_offscreenwindow.c",
    // "src/video/ps2/SDL_ps2video.c",
    // "src/video/psp/SDL_pspevents.c",
    // "src/video/psp/SDL_pspgl.c",
    // "src/video/psp/SDL_pspmouse.c",
    // "src/video/psp/SDL_pspvideo.c",
    // "src/video/qnx/SDL_qnxgl.c",
    // "src/video/qnx/SDL_qnxkeyboard.c",
    // "src/video/qnx/SDL_qnxvideo.c",
    // "src/video/raspberry/SDL_rpievents.c",
    // "src/video/raspberry/SDL_rpimouse.c",
    // "src/video/raspberry/SDL_rpiopengles.c",
    // "src/video/raspberry/SDL_rpivideo.c",
    // "src/video/riscos/SDL_riscosevents.c",
    // "src/video/riscos/SDL_riscosframebuffer.c",
    // "src/video/riscos/SDL_riscosmessagebox.c",
    // "src/video/riscos/SDL_riscosmodes.c",
    // "src/video/riscos/SDL_riscosmouse.c",
    // "src/video/riscos/SDL_riscosvideo.c",
    // "src/video/riscos/SDL_riscoswindow.c",
    // "src/video/vita/SDL_vitaframebuffer.c",
    // "src/video/vita/SDL_vitagl_pvr.c",
    // "src/video/vita/SDL_vitagles.c",
    // "src/video/vita/SDL_vitagles_pvr.c",
    // "src/video/vita/SDL_vitakeyboard.c",
    // "src/video/vita/SDL_vitamessagebox.c",
    // "src/video/vita/SDL_vitamouse.c",
    // "src/video/vita/SDL_vitatouch.c",
    // "src/video/vita/SDL_vitavideo.c",
    // "src/video/vivante/SDL_vivanteopengles.c",
    // "src/video/vivante/SDL_vivanteplatform.c",
    // "src/video/vivante/SDL_vivantevideo.c",
    // "src/video/vivante/SDL_vivantevulkan.c",
    "src/video/wayland/SDL_waylandclipboard.c",
    "src/video/wayland/SDL_waylanddatamanager.c",
    "src/video/wayland/SDL_waylanddyn.c",
    "src/video/wayland/SDL_waylandevents.c",
    "src/video/wayland/SDL_waylandkeyboard.c",
    "src/video/wayland/SDL_waylandmessagebox.c",
    "src/video/wayland/SDL_waylandmouse.c",
    "src/video/wayland/SDL_waylandopengles.c",
    "src/video/wayland/SDL_waylandshmbuffer.c",
    "src/video/wayland/SDL_waylandvideo.c",
    "src/video/wayland/SDL_waylandvulkan.c",
    "src/video/wayland/SDL_waylandwindow.c",
    // "src/video/x11/SDL_x11clipboard.c",
    // "src/video/x11/SDL_x11dyn.c",
    // "src/video/x11/SDL_x11events.c",
    // "src/video/x11/SDL_x11framebuffer.c",
    // "src/video/x11/SDL_x11keyboard.c",
    // "src/video/x11/SDL_x11messagebox.c",
    // "src/video/x11/SDL_x11modes.c",
    // "src/video/x11/SDL_x11mouse.c",
    // "src/video/x11/SDL_x11opengl.c",
    // "src/video/x11/SDL_x11opengles.c",
    // "src/video/x11/SDL_x11pen.c",
    // "src/video/x11/SDL_x11shape.c",
    // "src/video/x11/SDL_x11touch.c",
    // "src/video/x11/SDL_x11video.c",
    // "src/video/x11/SDL_x11vulkan.c",
    // "src/video/x11/SDL_x11window.c",
    // "src/video/x11/SDL_x11xfixes.c",
    // "src/video/x11/SDL_x11xinput2.c",
    // "src/video/x11/edid-parse.c",
};

const darwin_src_files = [_][]const u8{
    "src/haptic/darwin/SDL_syshaptic.c",
    // "src/hidapi/mac/hid.c",
    // "src/joystick/hidapi/SDL_hidapijoystick.c",
    "src/joystick/darwin/SDL_iokitjoystick.c",
    "src/power/macos/SDL_syspower.c",

    // shared with linux
    "src/filesystem/posix/SDL_sysfsops.c",
    "src/filesystem/unix/SDL_sysfilesystem.c",

    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_sysrwlock.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",
    "src/time/unix/SDL_systime.c",
    "src/timer/unix/SDL_systimer.c",
    "src/video/offscreen/SDL_offscreenevents.c",
    "src/video/offscreen/SDL_offscreenframebuffer.c",
    "src/video/offscreen/SDL_offscreenopengles.c",
    "src/video/offscreen/SDL_offscreenvideo.c",
    "src/video/offscreen/SDL_offscreenwindow.c",

    // why?
    "src/audio/disk/SDL_diskaudio.c",

    "src/joystick/hidapi/SDL_hidapi_combined.c",
    "src/joystick/hidapi/SDL_hidapi_gamecube.c",
    "src/joystick/hidapi/SDL_hidapi_luna.c",
    "src/joystick/hidapi/SDL_hidapi_ps3.c",
    "src/joystick/hidapi/SDL_hidapi_ps4.c",
    "src/joystick/hidapi/SDL_hidapi_ps5.c",
    "src/joystick/hidapi/SDL_hidapi_rumble.c",
    "src/joystick/hidapi/SDL_hidapi_shield.c",
    "src/joystick/hidapi/SDL_hidapi_stadia.c",
    "src/joystick/hidapi/SDL_hidapi_steam.c",
    "src/joystick/hidapi/SDL_hidapi_steamdeck.c",
    "src/joystick/hidapi/SDL_hidapi_switch.c",
    "src/joystick/hidapi/SDL_hidapi_wii.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360w.c",
    "src/joystick/hidapi/SDL_hidapi_xboxone.c",
    "src/joystick/hidapi/SDL_hidapijoystick.c",
};

const objective_c_src_files = [_][]const u8{
    "src/audio/coreaudio/SDL_coreaudio.m",
    "src/camera/coremedia/SDL_camera_coremedia.m",
    "src/dialog/cocoa/SDL_cocoadialog.m",
    "src/file/cocoa/SDL_iostreambundlesupport.m",
    "src/filesystem/cocoa/SDL_sysfilesystem.m",
    "src/hidapi/ios/hid.m",
    "src/joystick/apple/SDL_mfijoystick.m",
    "src/locale/macos/SDL_syslocale.m",
    // "src/main/ios/SDL_sysmain_callbacks.m",
    // "src/misc/ios/SDL_sysurl.m",
    "src/misc/macos/SDL_sysurl.m",
    "src/render/metal/SDL_render_metal.m",
    "src/sensor/coremotion/SDL_coremotionsensor.m",
    "src/video/cocoa/SDL_cocoaclipboard.m",
    "src/video/cocoa/SDL_cocoaevents.m",
    "src/video/cocoa/SDL_cocoakeyboard.m",
    "src/video/cocoa/SDL_cocoamessagebox.m",
    "src/video/cocoa/SDL_cocoametalview.m",
    "src/video/cocoa/SDL_cocoamodes.m",
    "src/video/cocoa/SDL_cocoamouse.m",
    "src/video/cocoa/SDL_cocoaopengl.m",
    "src/video/cocoa/SDL_cocoaopengles.m",
    "src/video/cocoa/SDL_cocoashape.m",
    "src/video/cocoa/SDL_cocoavideo.m",
    "src/video/cocoa/SDL_cocoavulkan.m",
    "src/video/cocoa/SDL_cocoawindow.m",
    "src/video/uikit/SDL_uikitappdelegate.m",
    "src/video/uikit/SDL_uikitclipboard.m",
    "src/video/uikit/SDL_uikitevents.m",
    "src/video/uikit/SDL_uikitmessagebox.m",
    "src/video/uikit/SDL_uikitmetalview.m",
    "src/video/uikit/SDL_uikitmodes.m",
    "src/video/uikit/SDL_uikitopengles.m",
    "src/video/uikit/SDL_uikitopenglview.m",
    "src/video/uikit/SDL_uikitvideo.m",
    "src/video/uikit/SDL_uikitview.m",
    "src/video/uikit/SDL_uikitviewcontroller.m",
    "src/video/uikit/SDL_uikitvulkan.m",
    "src/video/uikit/SDL_uikitwindow.m",
};

const windows_src_files = [_][]const u8{
    "src/core/windows/SDL_hid.c",
    "src/core/windows/SDL_immdevice.c",
    "src/core/windows/SDL_windows.c",
    "src/core/windows/SDL_xinput.c",
    "src/core/windows/pch.c",
    "src/dialog/windows/SDL_windowsdialog.c",
    "src/filesystem/windows/SDL_sysfilesystem.c",
    "src/filesystem/windows/SDL_sysfsops.c",
    "src/haptic/windows/SDL_dinputhaptic.c",
    "src/haptic/windows/SDL_windowshaptic.c",
    "src/hidapi/windows/hid.c",
    "src/hidapi/windows/hidapi_descriptor_reconstruct.c",
    // "src/hidapi/windows/pp_data_dump/pp_data_dump.c",
    // "src/hidapi/windows/test/hid_report_reconstructor_test.c",
    "src/joystick/windows/SDL_dinputjoystick.c",
    "src/joystick/windows/SDL_rawinputjoystick.c",
    "src/joystick/windows/SDL_windows_gaming_input.c",
    "src/joystick/windows/SDL_windowsjoystick.c",
    "src/joystick/windows/SDL_xinputjoystick.c",
    "src/loadso/windows/SDL_sysloadso.c",
    "src/locale/windows/SDL_syslocale.c",
    "src/misc/windows/SDL_sysurl.c",
    "src/power/windows/SDL_syspower.c",
    "src/sensor/windows/SDL_windowssensor.c",
    "src/thread/windows/SDL_syscond_cv.c",
    "src/thread/windows/SDL_sysmutex.c",
    "src/thread/windows/SDL_sysrwlock_srw.c",
    "src/thread/windows/SDL_syssem.c",
    "src/thread/windows/SDL_systhread.c",
    "src/thread/windows/SDL_systls.c",
    "src/time/windows/SDL_systime.c",
    "src/timer/windows/SDL_systimer.c",
    "src/video/windows/SDL_windowsclipboard.c",
    "src/video/windows/SDL_windowsevents.c",
    "src/video/windows/SDL_windowsframebuffer.c",
    "src/video/windows/SDL_windowskeyboard.c",
    "src/video/windows/SDL_windowsmessagebox.c",
    "src/video/windows/SDL_windowsmodes.c",
    "src/video/windows/SDL_windowsmouse.c",
    "src/video/windows/SDL_windowsopengl.c",
    "src/video/windows/SDL_windowsopengles.c",
    "src/video/windows/SDL_windowsrawinput.c",
    "src/video/windows/SDL_windowsshape.c",
    "src/video/windows/SDL_windowsvideo.c",
    "src/video/windows/SDL_windowsvulkan.c",
    "src/video/windows/SDL_windowswindow.c",
};
