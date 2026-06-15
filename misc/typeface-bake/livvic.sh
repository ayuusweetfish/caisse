process_variant() {
  i=$1
  r1=$2
  r2=$3
  hb-subset /tmp/Livvic/Livvic-$i.ttf --unicodes=$r1 --output-file=/tmp/1.ttf
  sfnt2woff /tmp/1.ttf
  woff2_compress /tmp/1.ttf
  for j in woff woff2; do mv /tmp/1.$j Livvic-$i-base.$j; done
  hb-subset /tmp/Livvic/Livvic-$i.ttf --unicodes=$r2 --output-file=/tmp/1.ttf
  sfnt2woff /tmp/1.ttf
  woff2_compress /tmp/1.ttf
  for j in woff woff2; do mv /tmp/1.$j Livvic-$i-ext.$j; done
  rm /tmp/1.ttf
}

process_variant Regular   0-7f,b0,b7,2010-201e,2026  80-af,b1-b6,b8-200f,201f-2025,2027-25ff
process_variant Medium          0-7f,2010-201e,2026  80-200f,201f-2025,2027-25ff
process_variant SemiBold        0-7f,2010-201e,2026  80-200f,201f-2025,2027-25ff
process_variant Italic          0-7f,2010-201e,2026  80-200f,201f-2025,2027-25ff
process_variant MediumItalic    0-7f,2010-201e,2026  80-200f,201f-2025,2027-25ff
process_variant SemiBoldItalic  0-7f,2010-201e,2026  80-200f,201f-2025,2027-25ff
