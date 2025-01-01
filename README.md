<!--
SPDX-FileCopyrightText: © 2024 Mark Delk <jethrodaniel@gmail.com>

SPDX-License-Identifier: Zlib
-->

# SDL.zig

Build [SDL](https://github.com/libsdl-org/SDL) using [zig](https://ziglang.org) (version 0.13.0).

Also includes

- [SDL_ttf](https://github.com/libsdl-org/SDL_ttf)

## Usage

TODO

## Tests

Build all of SDL's test programs:

```
zig build sdl-test
```

Build and run a specific SDL test:

```
zig build sdl-test-testaudiohotplug
zig build sdl-test-testcamera -- --camera 'Razer Kiyo'
```

## Examples

Build all of SDL's example programs:

```
zig build sdl-examples
```

Build and run a specific SDL example:

```
zig build sdl-examples-woodeneye
zig build sdl-examples-snake
```

Build all Zig examples:

```
zig build zig-examples
```

Build and run a specific Zig example:

```
zig build zig-examples-ttf
zig build zig-examples-minimal
```

## License

[Zlib](https://spdx.org/licenses/Zlib.html), same as [SDL](https://github.com/libsdl-org/SDL).
