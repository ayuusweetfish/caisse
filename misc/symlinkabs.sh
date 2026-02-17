if [ "$1" = "-r" ]; then
  shift
fi
ln -s "$(readlink -f "$1")" "$2"
