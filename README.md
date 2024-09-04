<!--
SPDX-FileCopyrightText: © 2024 Mark Delk <jethrodaniel@gmail.com>

SPDX-License-Identifier: Zlib
-->

# sdl.zig

Build [SDL](https://github.com/libsdl-org/SDL) using [zig](https://ziglang.org).

## License

[Zlib](https://spdx.org/licenses/Zlib.html), same as [SDL](https://github.com/libsdl-org/SDL).

### reuse

This project is using [reuse](https://reuse.software/) to ensure licensing is clear.

To update/add files:

```
reuse annotate -c "Mark Delk <jethrodaniel@gmail.com>" -l Zlib -y 2024 --copyright-style spdx-symbol --skip-existing --skip-unrecognised `fd -t f -H`

# NOTE: reuse doesn't yet support .{zig,zon} files, so do those separately
reuse annotate -c "Mark Delk <jethrodaniel@gmail.com>" -l Zlib -y 2024 --copyright-style spdx-symbol --skip-existing --style c `fd -t f | rg zig`
```

To confirm everything's in compliance:

```
reuse lint
```
