# Seasons
UNICODES=1f340,1f338,1f333,2600,1f33e,1f343,2744,1f9ca
# Internationalization, dark mode
UNICODES=${UNICODES},1f310,1f319,26aa
# External link, star
UNICODES=${UNICODES},1fa90,1f31f
# File types
UNICODES=${UNICODES},1f4e6,1f3a7,1f3b6,1f3bc,1f5bc,1f39e,1f4c3,1f47e
# Music track
UNICODES=${UNICODES},1f58c,1f3a4,1f4bf
pyftsubset NotoEmoji-Regular.ttf \
  --output-file=seasons-NotoEmoji.ttf \
  --unicodes=${UNICODES}
mv seasons-NotoEmoji.ttf little-icons.ttf
woff2_compress little-icons.ttf
mv little-icons.woff2 ../../content
rm little-icons.ttf
