SOLVE_EXEC=/tmp/caisse-typeface-zh-solve
if [[ ! -e "${SOLVE_EXEC}" ]]; then
  echo "Compiling solver"
  g++ solve.cc -std=c++11 -O2 -o ${SOLVE_EXEC}
fi

if [[ "$FULL" == "1" ]]; then
  find ../../build/ -name "index.*.html" -not -path "../../build/backyard/*" | perl -pe 's/(.+build\/(.+)\/[^\/]+\.([a-z]+)\.html)\n/\1\n\2.\3\n/g' | ${SOLVE_EXEC} > common.txt
fi
find ../../build/ -name "index.*.html" | perl -pe 's/(.+build\/(.+)\/[^\/]+\.([a-z]+)\.html)\n/\1\n\2.\3\n/g' | INC=1 ${SOLVE_EXEC} > /tmp/caisse-typeface-zh-stray.txt

exists() { [[ -f $1 ]]; }
exists ../../content/fonts-zh/AaKaiSong.*.woff2 && mv ../../content/fonts-zh/AaKaiSong.*.woff2 .
lua process.lua
test -n "$(find . -maxdepth 1 -name 'AaKaiSong.*.woff2' -print -quit)" && rm AaKaiSong.*.woff2
