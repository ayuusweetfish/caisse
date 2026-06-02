mkdir -p /tmp/caissebuild

SOLVE_EXEC=/tmp/caissebuild/typeface-zh-solve
if [ ! -e "${SOLVE_EXEC}" ]; then
  echo "Compiling solver"
  g++ solve.cc -std=c++11 -O2 -o ${SOLVE_EXEC}
fi

if [ ! -e "/tmp/caissebuild/typeface-zh-AaKaiSong2WanZi2_remapped.ttf" ]; then
  fontforge -lang=py -script AaKaiSong_remap.py
  hb-info /tmp/caissebuild/typeface-zh-AaKaiSong2WanZi2_remapped.ttf --list-unicodes | awk '/^U\+[0-9A-F][0-9A-F][0-9A-F][0-9A-F]/ {print substr($1,3)}' > /tmp/caissebuild/typeface-zh-AaKaiSong2WanZi2.charset.txt
  # otfinfo -u /tmp/caissebuild/typeface-zh-AaKaiSong2WanZi2_remapped.ttf | perl -pe 's/^uni([0-9A-F]+) .*$/\1/g'
  # ttx /tmp/caissebuild/typeface-zh-AaKaiSong2WanZi2_remapped.ttf -t cmap -o - | perl -ne 'if (/<cmap_format_4 platformID="0" platEncID="3"/ .. /<\/cmap_format_4/) { printf("%04X\n", hex($1)) if /code="0x([0-9a-f]+)"/i; }'
fi

if [ "$FULL" = "1" ]; then
  find ../../build/ -name "index.*.html" -not -path "../../build/backyard/*" | perl -pe 's/(.+build\/(.+)\/[^\/]+\.([a-z]+)\.html)\n/\1\n\2.\3\n/g' | ${SOLVE_EXEC} > common.txt
fi
find ../../build/ -name "index.*.html" | perl -pe 's/(.+build\/(.+)\/[^\/]+\.([a-z]+)\.html)\n/\1\n\2.\3\n/g' | INC=1 ${SOLVE_EXEC} > /tmp/caissebuild/typeface-zh-stray.txt

${LUA:-lua} process.lua
