if [[ "$FULL_DEBUG" == "1" ]]; then
  woff2_compress AaKaiSong2WanZi2.ttf
  mv AaKaiSong2WanZi2.woff2 ../../content/fonts-zh/AaKaiSong2-full.woff2
  exit
fi

g++ solve.cc -std=c++11 -O2
if [[ "$FULL" == "1" ]]; then
  find ../../build -name "index.zh.html" -not -path "../../build/backyard/*" | perl -pe 's/(.+build\/(.+)\/[^\/]+)/\1\2\n/g' | ./a.out > common.txt
fi
find ../../build -name "index.zh.html" | perl -pe 's/(.+build\/(.+)\/[^\/]+)/\1\2\n/g' | INC=1 ./a.out > stray.txt

exists() { [[ -f $1 ]]; }
exists ../../content/fonts-zh/AaKaiSong.*.woff2 && mv ../../content/fonts-zh/AaKaiSong.*.woff2 .
lua process.lua
test -n "$(find . -maxdepth 1 -name 'AaKaiSong.*.woff2' -print -quit)" && rm AaKaiSong.*.woff2
rm a.out
