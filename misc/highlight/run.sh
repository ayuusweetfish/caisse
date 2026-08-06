newly=

for f in gen/src.*; do
  hashext=${f#*.}
  ext=${f##*.}
  result=gen/res.$hashext.html
  if [ ! -e "$result" ]; then
    echo Processing $hashext
    chroma --lexer=$ext --html --html-only --html-tab-width=4 $f | perl -pIO -e 's/<\/?(code|pre)[^>]*>//g' > $result
    newly="$newly $result"
  else
    echo Skipping $hashext
  fi
done

if [ ! -z "$newly" ]; then
  echo "To remove newly generated files: rm$newly"
fi
