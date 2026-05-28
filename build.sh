#!/usr/bin/env bash

cd $(dirname ${BASH_SOURCE[0]})

LUA=${LUA:-luajit}
if [ -z "$CP_NO_STDIN" ]; then
  if [ ! -e /tmp/caisse-symlinkabs ]; then
    cc misc/symlinkabs.c -O2 -o /tmp/caisse-symlinkabs
  fi
  CP="/tmp/caisse-symlinkabs"
  CP_STDIN=1
elif [ ! -e build ] || [ "$(stat -c "%d" build/)" = "$(stat -c "%d" content/)" ]; then
  CP="cp -l"
  CP_R="cp -lr"
else
  CP="ln -sr"
  CP_R="ln -sr"
fi

if [[ "$*" == *"stat"* ]]; then
  echo "Updating stats"
  cd misc/stat

  find ../../content -type f \
    -not -path "../../content/fonts/*" \
    -not -path "../../content/fonts-zh/*" \
    -not -path "../../content/vendor/*" \
    -not -path "../../content/items/backyard/*" \
    -not -regex "\.\./\.\./content/[^/]*\.\(html\|css\|js\|txt\)" \
    -not -name "page.txt" \
    -not -name "*.caisse.json" \
    | $LUA build.lua database.tsv ../../content/

  find -L ../../content/items/backyard/*/* -type f \
    -not -path "../../content/items/backyard/timeline/*" \
    -not -name "page.txt" \
    | $LUA build.lua ../../content/items/backyard/stat_database.tsv ../../content/

  cd ../..
fi

CP="$CP" CP_R="$CP_R" CP_STDIN="$CP_STDIN" $LUA build.lua

if [ $? -eq 0 ] && [[ "$*" == *"dist"* ]]; then
  (cd misc/typeface-zh && LUA=$LUA sh run.sh)
  DIST=1 $LUA build.lua
fi
