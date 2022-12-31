~/Downloads/ffmpeg-5.0.1 \
  -r 60 -f image2 -start_number 0 -i video/%05d.png \
  -i Vividness.wav \
  -filter_complex '[1]adelay=2850|2850' \
  -vcodec libx264 -crf 32 -pix_fmt yuv420p \
  Vividness.mp4

# To replace audio:
# ~/Downloads/ffmpeg-5.0.1 -i Vividness-1.mp4 -i Vividness.wav -filter_complex '[1]adelay=2850|2850' -c:v copy Vividness.mp4
