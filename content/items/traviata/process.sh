j=1
scale=50
for i in 23 25 27 31 37 35 33 39 43 41 45 53 55 57 47 51 49
do
  magick pasted-image-$i.png -scale $scale% +level-colors black \( pasted-image-$i.png -scale $scale% -brightness-contrast 0x50 -negate -alpha Off \) -compose CopyOpacity -composite image-$(printf "%02d" $j).png
  j=$((j + 1))
done
