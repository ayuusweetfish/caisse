fontforge -lang=py -script build.py
woff2_compress little-icons.ttf
sfnt2woff little-icons.ttf
mv little-icons.woff2 little-icons.woff ../../content/fonts
rm little-icons.ttf
