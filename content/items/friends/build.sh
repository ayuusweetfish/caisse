# https://superuser.com/q/524793
process() {
  name=$1
  tint=$2
  convert $name.png -colorspace gray -negate -evaluate Multiply 0.2 -alpha copy \
    -channel rgb -set colorspace sRGB -fx $tint $name-bg.png
}

process alicez '#0047ab'
process chiyuru '#5a7894'
process pieris '#58b2dc'
process xhhdd '#333d42'
process webring '#010101'
