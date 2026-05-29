*🚧 Incomplete notes on building and updating the site*

## Building

- `sh build.sh`: Debug build
- `sh build.sh stat`: Update file metadata
- `sh build.sh dist`: Distribution mode (subset fonts)

Options:
- `render=index,fireflies`: Only render a subset of pages
- `LUA=luajit`: Use a specific Lua executable (Lua 5.4/LuaJIT)
- `CP="cp -l" CP_R="ln -s"`: Use specific file copying commands.
  - `CP_STDIN=1` writes file names through standard input rather than arguments.
  - `build.sh` automatically sets these to `cp -l`/`cp -lr` if `build/` is on the same device as `content/` (after following symlinks), and a symlink creator otherwise.

## Miscellaneous components

### File metadata (`stat`)

Dependency: ImageMagick (`identify`), FFmpeg (`ffprobe`), Poppler (`pdfinfo`)

`apt install imagemagick ffmpeg poppler-utils`

### Chinese typeface (`typeface-zh`)

Dependency: GCC (`g++`), \<either HarfBuzz (`hb-subset`) or Python fontTools (`pyftsubset`)\>, WOFF2 (`woff2_compress`)

`apt install g++ libharfbuzz-bin fonttools woff2` / `dnf install g++ harfbuzz fonttools woff2-tools`

`sh run.sh` to build all subsets.

*TODO: The site's build has a hard requirement on this run, due to subset WOFF2 files not being checked into the repository. This is less than ideal.*

### Little icons (`little-icons`)

Dependency: FontForge (`fontforge`), WOFF2 (`woff2_compress`), WOFF (`sfnt2woff`)

`apt install fontforge woff2 woff-tools` / `dnf install fontforge woff2-tools woff`

`sh build.sh` to build.

### Kaomoji (`kaomoji`)

Dependency: librsvg2 (`rsvg-convert`), \<either Deno (`deno`) or Node.js (`node`)\>

`apt install librsvg2-bin` / `dnf install librsvg2-tools`

Run `deno i` or `npm i` to install SVGO and its dependencies.

*TODO: Fonts should be stored somewhere. Refer to **fonts\_list.txt** for a list of file checksums.*

`lua build.lua` to build. If using Node.js, set `SVGO=node_modules/svgo/bin/svgo.js`.
