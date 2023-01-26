cd $(dirname ${BASH_SOURCE[0]})

if [[ "$*" == *"stat"* ]]; then
  echo "Updating stats"
  cd misc/stat

  find ../../content -type f \
    -not -path "../../content/fonts/*" \
    -not -path "../../content/fonts-zh/*" \
    -not -path "../../content/vendor/*" \
    -not -path "../../content/items/backyard/*" \
    -not -name "page.txt" \
    | lua build.lua database.tsv ../../content/

  find -L ../../content/items/backyard/*/* -type f \
    -not -path "../../content/items/backyard/timeline/*" \
    -not -name "page.txt" \
    | lua build.lua ../../content/items/backyard/stat_database.tsv ../../content/

  cd ../..
fi

lua build.lua

if [[ "$*" == *"dist"* ]]; then
  (cd misc/typeface-zh && sh run.sh)
  DIST=1 lua build.lua
fi
