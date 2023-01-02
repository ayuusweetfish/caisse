g++ solve.cc -std=c++11 -O2
if [[ "$FULL" == "1" ]]; then
  find ../../build -name "index.zh.html" | awk -F/ '{ print $0; print $(NF-1) }' | ./a.out > common.txt
fi
find ../../build -name "index.zh.html" | awk -F/ '{ print $0; print $(NF-1) }' | INC=1 ./a.out > stray.txt
lua process.lua
for i in AaKaiSong.*.ttf; do woff2_compress $i; rm $i; done
rm ../../content/fonts-zh/AaKaiSong.*
mv AaKaiSong.*.woff2 ../../content/fonts-zh
rm a.out
