pyftsubset NotoEmoji-Regular.ttf \
  --output-file=seasons-NotoEmoji.ttf \
  --unicodes=1f340,1f338,1f333,2600,1f33e,1f343,2744,1f9ca
mv seasons-NotoEmoji.ttf little-icons.ttf
woff2_compress little-icons.ttf
mv little-icons.woff2 ../../content
rm little-icons.ttf
