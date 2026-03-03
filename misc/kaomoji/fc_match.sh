#!/bin/bash

input_string="$1"
font="$2"

config=$(mktemp)
cat >${config} <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir prefix="cwd">fonts</dir>
  <cachedir>/tmp/fc-cache</cachedir>
</fontconfig>
EOF

export FONTCONFIG_FILE=${config}

for (( i=0; i<${#input_string}; i++ )); do
  char="${input_string:$i:1}"
  cp=$(printf "%04X" "'$char")
  echo -n "U+${cp} [$char] ${font} -> "
  fc-match "${font}:charset=${cp}"
done

rm ${config}
