specified="$*"

# https://superuser.com/q/524793
process() {
  name=$1
  tint=$2
  if [[ "$specified" != "" ]] && [[ "$specified" != *"$name"* ]]; then
    return
  fi
  echo Processing $name
  convert $name.png -scale x300 -colorspace gray -negate -evaluate Multiply 0.2 -alpha copy \
    -channel rgb -set colorspace sRGB -fx $tint $name-bg.png
}

process alicez '#0047ab'
process chiyuru '#5a7894'
process pieris '#58b2dc'
process xhhdd '#333d42'
process tianxianzi '#ada99e'  # dimmed to 75%
process miyehn '#394134'
process gregueria '#4e4b5f'
process orangii '#ff9700'
process xxiivv-webring '#303030'
process indiewebring '#ff5c00'
process travellings '#303030'
