# IMAGEOPTIM=~/Downloads/ImageOptim.app/Contents/MacOS/ImageOptim FFMPEG=~/Downloads/ffmpeg-5.0.1 sh %

CONVERT="${CONVERT:-convert}"
FFMPEG="${FFMPEG:-ffmpeg}"
IMAGEOPTIM="${IMAGEOPTIM:-ImageOptim}"

echo "Using convert = ${CONVERT}"
echo "Using ffmpeg = ${FFMPEG}"

process_dir() {
  src_dir=$1
  dst_dir=$2
  echo "Source: $src_dir; Destination: $dst_dir"
  mkdir -p $dst_dir
  for f in `find "$src_dir" -type f`; do
    bn=`basename $f`
    ext=`echo ${bn##*.} | tr '[:upper:]' '[:lower:]'`
    dst=$dst_dir/$bn
    if [ ! -e "$dst" ]; then
      echo "Processing: $f -> $dst"
      if [ "$ext" == "jpg" ] || [ "$ext" == "jpeg" ] || [ "$ext" == "png" ] || [ "$ext" == "gif" ]
      then
        $CONVERT $f -scale "1000x1000>" $dst
        $IMAGEOPTIM $dst
      elif [ "$ext" == "mp4" ]
      then
        $FFMPEG -i $f -vf "scale='min(500,iw)':-2" $dst
      else
        echo "=== Unknown extension: $ext ==="
      fi
    fi
  done
}

process_dir pics_weibo pics_weibo_compressed
process_dir pics_closed_social pics_closed_social_compressed
