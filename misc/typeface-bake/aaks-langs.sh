hb-subset ../../misc/typeface-zh/AaKaiSong2WanZi2.ttf --text="汉语英语" --output-file=/tmp/1.ttf
sfnt2woff /tmp/1.ttf
woff2_compress /tmp/1.ttf
for j in woff woff2; do mv /tmp/1.$j AaKaiSong-langs.$j; done
rm /tmp/1.ttf
