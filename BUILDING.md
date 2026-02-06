*🚧 Incomplete notes on building and updating the site*

## Building

- `bash build.sh`: Debug build
- `bash build.sh stats`: Update file metadata
- `bash build.sh dist`: Distribution mode (subset fonts)

## Miscellaneous components

### File metadata (`stats`)

Dependency: ImageMagick (`identify`), FFmpeg (`ffprobe`), Poppler (`pdfinfo`)

`apt install imagemagick ffmpeg poppler-utils`

### Chinese typeface (`typeface-zh`)

Dependency: GCC (`g++`), Python `fonttools` (`pyftsubset`), WOFF2 (`woff2_compress`)

`apt install g++ fonttools woff2` / `dnf install g++ fonttools woff2-tools`

`bash run.sh` to build all subsets.

*TODO: The site's build has a hard requirement on this run, due to subset WOFF2 files not being checked into the repository. This is less than ideal.*
