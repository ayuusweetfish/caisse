process_variant() {
  i=$1
  r1=$2
  r2=$3
  fonttools subset /mnt/data/downloads/Livvic/Livvic-$i.ttf --unicodes=$r1 --output-file=/tmp/1.ttf
  sfnt2woff /tmp/1.ttf
  woff2_compress /tmp/1.ttf
  for j in woff woff2; do mv /tmp/1.$j Livvic-$i-ASCII.$j; done
  fonttools subset /mnt/data/downloads/Livvic/Livvic-$i.ttf --unicodes=$r2 --output-file=/tmp/1.ttf
  sfnt2woff /tmp/1.ttf
  woff2_compress /tmp/1.ttf
  for j in woff woff2; do mv /tmp/1.$j Livvic-$i-Ext.$j; done
}

process_variant Regular   0-7f,b0,b7,2010-201e  80-af,b1-b6,b8-200f,201f-25ff
process_variant Medium    0-7f,2010-201e        80-200f,201f-25ff
process_variant SemiBold  0-7f,2010-201e        80-200f,201f-25ff
