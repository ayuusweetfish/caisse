g++ solve.cc -std=c++11 -O2
if [[ "$FULL" == "1" ]]; then
  find ../../build -name "index.zh.html" -not -path "../../build/backyard/*" | perl -pe 's/(.+build\/(.+)\/[^\/]+)/\1\2\n/g' | ./a.out > common.txt
fi
find ../../build -name "index.zh.html" | perl -pe 's/(.+build\/(.+)\/[^\/]+)/\1\2\n/g' | INC=1 ./a.out > stray.txt

mv ../../content/fonts-zh/AaKaiSong.*.woff2 .
lua process.lua
[ -e AaKaiSong.*.woff2 ] && rm AaKaiSong.*.woff2
rm a.out
