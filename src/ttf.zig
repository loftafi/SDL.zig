// SPDX-FileCopyrightText: © 2024 Mark Delk <jethrodaniel@gmail.com>
//
// SPDX-License-Identifier: Zlib

const std = @import("std");
const c = @import("sdl").c;

const font_file = @import("fonts").intel_one_mono_regular;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    //

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.log.err("Unable to initialize SDL: {s}", .{c.SDL_GetError()});
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    if (!c.TTF_Init()) {
        std.log.err("TTF_Init: {s}", .{c.SDL_GetError()});
        return error.TTF_Init;
    }
    defer c.SDL_Quit();

    const data_dir_cstr = c.SDL_GetBasePath() orelse {
        std.log.err("SDL_GetBasePath: {s}", .{c.SDL_GetError()});
        return error.SDL_GetBasePath;
    };

    const data_dir = std.mem.span(data_dir_cstr);
    std.log.debug("data_dir: {s}\n", .{data_dir});

    std.log.debug("font_file.len: {d}", .{font_file.len});
    const font_buffer = c.SDL_IOFromConstMem(font_file, font_file.len) orelse {
        std.log.err("SDL_IOFromConstMem: {s}", .{c.SDL_GetError()});
        return error.SDL_IOFromConstMem;
    };

    const font = c.TTF_OpenFontIO(font_buffer, false, 30) orelse {
        std.log.err("TTF_OpenFontIO: {s}", .{c.SDL_GetError()});
        return error.TTF_OpenFontIO;
    };
    defer c.TTF_CloseFont(font);

    const window = c.SDL_CreateWindow(
        "Example SDL2 window",
        400,
        400,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.log.err("SDL_CreateWindow: {s}", .{c.SDL_GetError()});
        return error.SDL_CreateWindow;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(
        window,
        null,
    ) orelse {
        std.log.err("SDL_CreateRenderer: {s}", .{c.SDL_GetError()});
        return error.SDL_CreateRenderer;
    };
    defer c.SDL_DestroyRenderer(renderer);

    var quit = false;
    var text: []const u8 = "";

    while (!quit) {
        const start_time = c.SDL_GetTicks();

        var event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    std.log.debug("exit", .{});
                    quit = true;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        c.SDLK_A => {
                            std.log.debug("a", .{});
                            text = "a";
                        },
                        else => {
                            std.log.debug("something else", .{});
                            text = "oof";
                        },
                    }
                },
                c.SDL_EVENT_WINDOW_RESIZED => {
                    std.log.debug("resized", .{});
                },
                else => {},
            }
        }

        // clear screen
        if (!c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 0)) {
            std.log.err("SDL_SetRenderDrawColor: {s}", .{c.SDL_GetError()});
            return error.SDL_SetRenderDrawColor;
        }
        _ = c.SDL_RenderClear(renderer);

        // render text
        if (!std.mem.eql(u8, text, "")) {
            const color = c.SDL_Color{
                .r = 0,
                .g = 0,
                .b = 0,
                .a = @floor(0.87 * 255),
            };

            const c_str = try allocator.dupeZ(u8, text);
            const text_surface = c.TTF_RenderText_Solid(font, c_str, color) orelse {
                std.log.err("TTF_RenderText_Solid: {s}", .{c.SDL_GetError()});
                return error.TTF_RenderText_Solid;
            };
            defer c.SDL_DestroySurface(text_surface);

            const texture = c.SDL_CreateTextureFromSurface(renderer, text_surface) orelse {
                std.log.err("SDL_CreateTextureFromSurface: {s}", .{c.SDL_GetError()});
                return error.SDL_CreateTextureFromSurface;
            };
            defer c.SDL_DestroyTexture(texture);

            const rect = c.SDL_FRect{
                .x = 42,
                .y = 42,
                .w = @floatFromInt(text_surface.*.w),
                .h = @floatFromInt(text_surface.*.h),
            };

            _ = c.SDL_RenderTexture(renderer, texture, null, &rect);
        }

        _ = c.SDL_RenderPresent(renderer);

        const end_time = c.SDL_GetTicks();
        const elapsed = end_time - start_time;

        const FRAMES_PER_SECOND = 60;
        const MS_PER_FRAME = 1_000 / FRAMES_PER_SECOND;

        const delay = if (elapsed >= MS_PER_FRAME)
            MS_PER_FRAME
        else
            MS_PER_FRAME - elapsed;

        c.SDL_DelayNS(delay * std.time.ns_per_ms);
    }
}
