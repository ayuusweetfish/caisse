yes | ~/Downloads/ffmpeg-5.0.1 \
  -ss 3 -to 250 -i ~/Desktop/f/e/d/c/b/a/9/8/7/6/1/Frivolity_Cinema.mov \
  -itsoffset 0.48 -i ~/Desktop/f/e/d/c/b/a/9/8/7/6/1/2_1.wav \
  -vf "scale=iw/4:ih/4" -crf 30 Frivolity.mp4
