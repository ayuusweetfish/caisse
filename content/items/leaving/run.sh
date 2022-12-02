for i in {1..4}; do
  ./unifystrokes $ORIG_DIR/Tan$i.jpg Tan$i.png 35 20 80 255 171 49
  convert Tan$i.png -scale 360x640 Tan$i.png
done
for i in {1..4}; do
  ./unifystrokes $ORIG_DIR/Vio$i.jpg Vio$i.png 35 20 50 117 91 198
  convert Vio$i.png -scale 360x640 Vio$i.png
done
for i in {1..3}; do
  ./unifystrokes $ORIG_DIR/Azu$i.jpg Azu$i.png 35 20 80 42 182 243
  convert Azu$i.png -scale 360x640 Azu$i.png
done
for i in {1..2}; do
  ./unifystrokes $ORIG_DIR/Oli$i.jpg Oli$i.png 35 20 70 91 183 134
  convert Oli$i.png -scale 360x640 Oli$i.png
done
