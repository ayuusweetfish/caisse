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

`apk add imagemagick ffmpeg poppler-utils` / `dnf install ImageMagick ffmpeg poppler-utils` / `apt install imagemagick ffmpeg poppler-utils`

### Chinese typeface (`typeface-zh`)

Dependency: GCC (`g++`), FontForge (`fontforge`), HarfBuzz (`hb-subset`, `hb-info`), WOFF2 (`woff2_compress`)

`apk add g++ fontforge harfbuzz-utils woff2` / `dnf install g++ fontforge harfbuzz woff2-tools` / `apt install g++ fontforge libharfbuzz-bin woff2`

`sh run.sh` to build all subsets.

*TODO: The site’s distribution build has a hard requirement on this run, due to subset WOFF2 files not being checked into the repository. This is less than ideal.*

### Prebuilt subset fonts (`typeface-bake`)

Dependency: HarfBuzz (`hb-subset`), WOFF2 (`woff2_compress`), WOFF (`sfnt2woff`)

`apk add harfbuzz-utils woff2` / `dnf install harfbuzz woff2-tools woff` / `apt install libharfbuzz-bin woff2 woff-tools`

`sh <name>.sh` to build a subset.

For Alpine Linux where `sfnt2woff` is not readily available, consider `fontforge -lang=py -c 'import fontforge, sys; f = fontforge.open(sys.argv[1]); f.generate(sys.argv[1][:-4] + ".woff")'`.

### Little icons (`little-icons`)

Dependency: FontForge (`fontforge`), WOFF2 (`woff2_compress`), WOFF (`sfnt2woff`)

`apk add fontforge woff2` / `dnf install fontforge woff2-tools woff` / `apt install fontforge woff2 woff-tools`

`sh build.sh` to build.

### Kaomoji (`kaomoji`)

Dependency: librsvg2 (`rsvg-convert`), \<either Deno (`deno`) or Node.js (`node`)\>

`apk add rsvg-convert` / `dnf install librsvg2-tools` / `apt install librsvg2-bin`

Run `deno i` or `npm i` to install SVGO and its dependencies.

*TODO: Fonts should be stored somewhere. Refer to **fonts\_list.txt** for a list of file checksums.*

`lua build.lua` to build. If using Node.js, set `SVGO=node_modules/svgo/bin/svgo.js`.
