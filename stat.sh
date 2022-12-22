cd misc/stat
find ../../content -type f \
  -not -path "../../content/fonts/*" \
  -not -path "../../content/fonts-zh/*" \
  -not -path "../../content/vendor/*" \
  | lua build.lua ../../content/
