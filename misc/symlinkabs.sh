if [ "$1" = "-r" ]; then
  shift
fi
ln -s "$PWD/$1" "$2"
