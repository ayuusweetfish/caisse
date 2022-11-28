pyftsubset NotoEmoji-Regular.ttf \
  --output-file=seasons-NotoEmoji.ttf \
  --unicodes=1f340,1f333,1f343,2744
mv seasons-NotoEmoji.ttf little-icons.ttf
woff2_compress little-icons.ttf
mv little-icons.woff2 ../../content
rm little-icons.ttf
