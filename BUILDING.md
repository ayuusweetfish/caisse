*🚧 Incomplete notes on building and updating the site*

## Building

- `bash build.sh`: Debug build
- `bash build.sh stats`: Update file metadata
- `bash build.sh dist`: Distribution mode (subset fonts)

Options:
- `render=index,fireflies`: Only render a subset of pages
- `LUA=luajit`: Use a specific Lua executable (Lua 5.4/LuaJIT)
- `CP="cp -l"`: Use a specific file copying command. Should support `-r` argument for recursive copy.
  - `build.sh` automatically sets this to `cp -r` if `build/` is on the same device as `content/` (after following symlinks), and a symlink creator otherwise.

## Miscellaneous components

### File metadata (`stats`)

Dependency: ImageMagick (`identify`), FFmpeg (`ffprobe`), Poppler (`pdfinfo`)

`apt install imagemagick ffmpeg poppler-utils`

### Chinese typeface (`typeface-zh`)

Dependency: GCC (`g++`), Python `fonttools` (`pyftsubset`), WOFF2 (`woff2_compress`)

`apt install g++ fonttools woff2` / `dnf install g++ fonttools woff2-tools`

`bash run.sh` to build all subsets.

*TODO: The site's build has a hard requirement on this run, due to subset WOFF2 files not being checked into the repository. This is less than ideal.*

### Little icons (`little-icons`)

Dependency: FontForge (`fontforge`), WOFF2 (`woff2_compress`), WOFF (`sfnt2woff`)

`apt install fontforge woff2 woff-tools` / `dnf install fontforge woff2-tools woff`

`sh build.sh` to build.

### Kaomoji (`kaomoji`)

Dependency: librsvg2 (`rsvg-convert`), Node.js (`node`)

`apt install librsvg2-bin` / `dnf install librsvg2-tools`

Run `npm i` to install SVGO and its dependencies.

*TODO: Fonts should be stored somewhere. Refer to **fonts\_list.txt** for a list of file checksums.*

`lua build.lua` to build.
