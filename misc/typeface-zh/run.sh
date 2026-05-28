SOLVE_EXEC=/tmp/caisse-typeface-zh-solve
if [ ! -e "${SOLVE_EXEC}" ]; then
  echo "Compiling solver"
  g++ solve.cc -std=c++11 -O2 -o ${SOLVE_EXEC}
fi

if [ "$FULL" = "1" ]; then
  find ../../build/ -name "index.*.html" -not -path "../../build/backyard/*" | perl -pe 's/(.+build\/(.+)\/[^\/]+\.([a-z]+)\.html)\n/\1\n\2.\3\n/g' | ${SOLVE_EXEC} > common.txt
fi
find ../../build/ -name "index.*.html" | perl -pe 's/(.+build\/(.+)\/[^\/]+\.([a-z]+)\.html)\n/\1\n\2.\3\n/g' | INC=1 ${SOLVE_EXEC} > /tmp/caisse-typeface-zh-stray.txt

if [ ! -e "/tmp/caisse-typeface-zh-AaKaiSong2WanZi2_remapped.ttf" ]; then
  fontforge -lang=py -script AaKaiSong_remap.py
fi
${LUA:-lua} process.lua
