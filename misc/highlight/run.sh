# $ chroma --version
# 2.4.0-aecedef97da5c01d46cd3c8b427df5aae92b3089-2022-11-17T22:13:11Z

newly=

for f in src.*; do
  hashext=${f#*.}
  ext=${f##*.}
  result=res.$hashext.html
  if [ ! -e "$result" ]; then
    echo Processing $hashext
    chroma --lexer=$ext --html --html-only --html-tab-width=4 $f | perl -pIO -e 's/<\/?(code|pre)[^>]*>//g' > $result
    newly="$newly *$hashext*"
  else
    echo Skipping $hashext
  fi
done

if [ ! -z "$newly" ]; then
  echo "To remove newly generated files: rm$newly"
fi
