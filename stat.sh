cd misc/stat

find ../../content -type f \
  -not -path "../../content/fonts/*" \
  -not -path "../../content/fonts-zh/*" \
  -not -path "../../content/vendor/*" \
  -not -path "../../content/items/backyard/*" \
  -not -name "page.txt" \
  | lua build.lua database.tsv ../../content/

find ../../content/items/backyard/*/* -type f \
  -not -name "page.txt" \
  | lua build.lua ../../content/items/backyard/stat_database.tsv ../../content/
