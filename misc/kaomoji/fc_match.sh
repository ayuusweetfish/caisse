#!/bin/bash

# bash fc_match.sh '人a♡123' 'Noto Sans'

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
  fc_output=$(fc-match "${font}:charset=${cp}")
  matched_family=$(echo "$fc_output" | sed -n 's/^[^:]*: "\([^"]*\)".*$/\1/p')
  if [[ "${matched_family}" != "${font}" ]]; then
    echo -ne '\033[0;33m'
  fi
  echo -n "U+${cp} [$char] ${font} -> ${fc_output}"
  echo -ne '\033[0m\n'
done

rm ${config}
